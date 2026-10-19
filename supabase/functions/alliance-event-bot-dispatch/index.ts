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
 if(!details.ok){await final(job,"failed",null,"channel_check_http_"+details.status);return "failed";}
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
Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return json({error:"method_not_allowed"},405);
 try{
  const provided=req.headers.get("x-alliance-event-key")||"";
  const settings=await checked<any>(db.from("aos_event_bot_settings").select("scheduler_key,sending_enabled,production_approved").eq("id",1).single());
  if(!provided||provided!==settings.scheduler_key)return json({error:"unauthorized"},401);
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
