import { createClient } from "npm:@supabase/supabase-js@2.58.0";

const endpoint = Deno.env.get("SUPABASE_URL")!;
const db = createClient(endpoint, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {auth:{persistSession:false}});
const version = "0.1.0";
const json = (x:unknown,s=200)=>new Response(JSON.stringify(x),{status:s,headers:{"content-type":"application/json","cache-control":"no-store"}});
type Job = {id:string; claim_token:string; alliance_code:string; content:string; channel_id:string; role_id:string|null; status:string; attempts:number};
async function checked<T>(call:PromiseLike<{data:T|null;error:any}>):Promise<T>{
 const {data,error}=await call;if(error)throw new Error("database:"+String(error.code||error.message||"unknown"));return data as T;
}
async function final(job:Job,status:"sent"|"failed"|"uncertain",id:string|null=null,reason:string|null=null,detail:string|null=null,retry:number|null=null){
 return checked(db.rpc("aos_event_bot_finish",{p_id:job.id,p_token:job.claim_token,
  p_status:status,p_discord_id:id,p_error:reason,p_detail:detail,p_retry_seconds:retry}));
}
async function dispatch(job:Job,token:string){
 const role=job.role_id && /^[0-9]{17,20}$/.test(job.role_id)?job.role_id:null;
 // No @everyone, @here, arbitrary user or arbitrary role pings.
 const content=(role?"<@&"+role+">\n":"")+job.content;
 if(content.length>2000){await final(job,"failed",null,"content_too_long","Discord limit is 2000 characters");return "failed";}
 // Verify that the configured destination is actually in the selected Discord guild.
 const guild=await checked<any>(db.from("aos_discord_bot_config")
   .select("guild_id").eq("alliance_code",job.alliance_code).maybeSingle());
 let details:Response;
 try{details=await fetch("https://discord.com/api/v10/channels/"+job.channel_id,{
  headers:{authorization:"Bot "+token},signal:AbortSignal.timeout(9000)
 })}catch(e){await final(job,"failed",null,"channel_check_unavailable",String(e),30);return "retry";}
 if(!details.ok){
  if(details.status===429||details.status>=500){
   let retry=30;
   if(details.status===429){
    const data=await details.json().catch(()=>({}));
    const retryAfter=Number(data?.retry_after||details.headers.get("retry-after")||10);
    retry=Number.isFinite(retryAfter)?Math.max(5,Math.ceil(retryAfter)+1):30;
   }
   await final(job,"failed",null,"channel_check_http_"+details.status,"retry channel validation",retry);
   return "retry";
  }
  await final(job,"failed",null,"channel_check_http_"+details.status);return "failed";
 }
 const destination=await details.json().catch(()=>null);
 if(!guild?.guild_id || destination?.guild_id!==guild.guild_id){
   await final(job,"failed",null,"discord_guild_mismatch");return "failed";
 }
 const payload={content,nonce:job.id.replace(/-/g,"").slice(0,24),enforce_nonce:true,
  allowed_mentions:role?{roles:[role],users:[],replied_user:false}:{parse:[]}};
 let response:Response;
 try {
  response=await fetch("https://discord.com/api/v10/channels/"+job.channel_id+"/messages",{
   method:"POST",headers:{"authorization":"Bot "+token,"content-type":"application/json"},
   body:JSON.stringify(payload),signal:AbortSignal.timeout(12500)
  });
 } catch(e) {
  // A timed-out POST could have succeeded. Never blindly repeat.
  await final(job,"uncertain",null,"ambiguous_network_error",String(e).slice(0,300));return "uncertain";
 }
 if(response.ok){
  const message=await response.json().catch(()=>null);
  if(!message?.id){await final(job,"uncertain",null,"discord_missing_message_id");return "uncertain";}
  await final(job,"sent",String(message.id));return "sent";
 }
 const body=await response.text().catch(()=>"");
 if(response.status===429){
  let parsed:any={};try{parsed=JSON.parse(body)}catch{}
  const retry=Math.ceil(Number(parsed.retry_after||response.headers.get("retry-after")||5));
  await final(job,"failed",null,"rate_limited",body.slice(0,280),Number.isFinite(retry)?retry+1:10);return "retry";
 }
 if(response.status>=500){
  await final(job,"uncertain",null,"discord_server_ambiguous",String(response.status));return "uncertain";
 }
 // Authentication, permissions, deleted channel, bad payload: permanent failure.
 await final(job,"failed",null,"discord_http_"+response.status,body.slice(0,280));return "failed";
}
// Read-only connectivity probe. Never sends a Discord message or changes send gates.
async function diagnoseConnection(){
 const token=Deno.env.get("ALLIANCE_EVENT_DISCORD_TOKEN")?.trim();
 if(!token)return {ok:false,code:"discord_token_missing"};
 const headers={authorization:"Bot "+token};
 let botResponse:Response;
 try{botResponse=await fetch("https://discord.com/api/v10/users/@me",{headers,signal:AbortSignal.timeout(7000)});}
 catch{return {ok:false,code:"discord_api_unreachable"};}
 if(!botResponse.ok)return {ok:false,code:"discord_auth_http_"+botResponse.status};
 const bot=await botResponse.json().catch(()=>null);
 if(!bot?.id||!bot?.bot)return {ok:false,code:"discord_bot_identity_invalid"};
 const configs=await checked<any[]>(db.from("aos_discord_bot_config").select("alliance_code,guild_id,channels"));
 const configuredRoleMentions:Record<string,unknown>={};
 for(const cfg of configs){
  try{
   const [rs,onboarding]=await Promise.all([
    fetch("https://discord.com/api/v10/guilds/"+cfg.guild_id+"/roles",{headers,signal:AbortSignal.timeout(7000)}),
    checked<any>(db.from("alliance_discord_config").select("language_role_ids").eq("alliance_code",cfg.alliance_code).eq("guild_id",cfg.guild_id).eq("active",true).maybeSingle())
   ]);
   const roles=rs.ok?await rs.json().catch(()=>[]):[];
   configuredRoleMentions[cfg.alliance_code]={http_status:rs.status,roles:Object.fromEntries(["de","en","fr","es"].map(lang=>{
    const id=onboarding?.language_role_ids?.[lang];
    const x=Array.isArray(roles)?roles.find((x:any)=>x.id===id):undefined;
    return [lang,{configured:!!id,exists:!!x,mentionable:!!x?.mentionable,name:x?.name||null}];
   }))};
  }catch{configuredRoleMentions[cfg.alliance_code]={error:"roles_unavailable"};}
 }
 const allGuildChannels:Record<string,unknown>={};
 for(const c of configs){
  if(!c.guild_id||allGuildChannels[c.guild_id])continue;
  try{
   const ch=await fetch("https://discord.com/api/v10/guilds/"+c.guild_id+"/channels",{headers,signal:AbortSignal.timeout(8000)});
   const rows=ch.ok?await ch.json().catch(()=>[]):[];
   allGuildChannels[c.guild_id]={status:ch.status,channels:Array.isArray(rows)?rows.filter((x:any)=>[0,5].includes(x.type)).map((x:any)=>({id:x.id,name:x.name,type:x.type})).slice(0,100):[]};
  }catch{allGuildChannels[c.guild_id]={status:0,channels:[]};}
 }
 const alliances=[];
 for(const config of configs){
   const channels:Record<string,unknown>={};
   for(const lang of ["de","en","fr","es"]){
     const id=config.channels?.[lang];
     if(typeof id!=="string"||!/^[0-9]{17,20}$/.test(id)){
       channels[lang]={ok:false,code:"not_configured"};continue;
     }
     try{
       const reply=await fetch("https://discord.com/api/v10/channels/"+id,{headers,signal:AbortSignal.timeout(7000)});
       if(!reply.ok){channels[lang]={ok:false,code:"discord_http_"+reply.status};continue;}
       const obj=await reply.json().catch(()=>null);
       channels[lang]={ok:obj?.guild_id===config.guild_id,code:obj?.guild_id===config.guild_id?"channel_accessible":"guild_mismatch"};
     }catch{channels[lang]={ok:false,code:"discord_api_unreachable"};}
   }
   alliances.push({alliance:config.alliance_code,configured:!!config.guild_id,channels});
 }
 return {ok:true,bot:{id:String(bot.id),username:String(bot.username||"")},alliances,allGuildChannels,configuredRoleMentions,notes:"Channel access confirms readability, not Send Messages permission."};
}
Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return json({error:"method_not_allowed"},405);
 try{
  const provided=req.headers.get("x-alliance-event-key")||"";
  const settings=await checked<any>(db.from("aos_event_bot_settings").select("scheduler_key,sending_enabled,production_approved").eq("id",1).single());
  if(!provided||provided!==settings.scheduler_key)return json({error:"unauthorized"},401);
  const body=await req.json().catch(()=>({}));
  if(body?.action==="diagnose")return json(await diagnoseConnection());
  const cycles=await checked<number>(db.rpc("aos_event_bot_refresh"));
  const manuals=await checked<number>(db.rpc("aos_event_bot_refresh_manual"));
  const n=cycles+manuals;
  await checked(db.from("aos_event_bot_heartbeat").update({
   last_check:new Date().toISOString(),last_success:new Date().toISOString(),
   last_error:null,dispatcher_version:version,updated_at:new Date().toISOString()
  }).eq("id",1));
  if(!settings.sending_enabled||!settings.production_approved)return json({ok:true,version,refreshed:n,delivery:"globally_disabled_or_unapproved"});
  const token=Deno.env.get("ALLIANCE_EVENT_DISCORD_TOKEN");
  if(!token){
   await checked(db.from("aos_event_bot_heartbeat").update({last_error:"discord_token_not_configured"}).eq("id",1));
   return json({ok:true,version,refreshed:n,delivery:"token_missing"});
  }
  const jobs=await checked<Job[]>(db.rpc("aos_event_bot_claim",{p_limit:20}));
  const outcome:Record<string,number>={};
  let index=0;
  await Promise.all(Array.from({length:Math.min(4,jobs.length)},async()=>{
   while(index<jobs.length){
    const job=jobs[index++];
    let result="uncertain";
    try{result=await dispatch(job,token)}
    catch(e){
     // Database finalization or network failure after POST could have sent.
     try{await final(job,"uncertain",null,"dispatch_exception",String(e).slice(0,220))}catch{}
    }
    outcome[result]=(outcome[result]||0)+1;
   }
  }));
  await checked(db.from("aos_event_bot_heartbeat").update({last_processed:jobs.length,updated_at:new Date().toISOString()}).eq("id",1));
  return json({ok:true,version,refreshed:n,claimed:jobs.length,outcome});
 }catch(e){
  try{await db.from("aos_event_bot_heartbeat").update({last_check:new Date().toISOString(),last_error:String(e).slice(0,300)}).eq("id",1)}catch{}
  console.error("event-bot-dispatch",String(e));
  return json({error:"dispatcher_failed"},500);
 }
});
