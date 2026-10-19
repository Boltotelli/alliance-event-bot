import {createClient} from "npm:@supabase/supabase-js@2.58.0";
const url=Deno.env.get("SUPABASE_URL")!;
const publishable=Deno.env.get("SUPABASE_ANON_KEY")!;
const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const auth=createClient(url,publishable,{auth:{persistSession:false}});
const db=createClient(url,service,{auth:{persistSession:false}});
const origins=new Set(["https://boltotelli.github.io","https://welcome-nrw.vercel.app","http://localhost:3000","http://127.0.0.1:3000"]);
function headers(req:Request){
 const origin=req.headers.get("origin")||"";
 return {"content-type":"application/json","cache-control":"no-store","vary":"Origin",
  ...(origins.has(origin)?{"access-control-allow-origin":origin}:{}),
  "access-control-allow-headers":"authorization,apikey,content-type",
  "access-control-allow-methods":"GET,POST,OPTIONS"};
}
function response(req:Request,val:unknown,status=200){return new Response(JSON.stringify(val),{status,headers:headers(req)})}
class HttpError extends Error{constructor(public code:string,public status=400){super(code)}}
async function checked<T>(call:PromiseLike<{data:T|null,error:any}>):Promise<T>{
 const {data,error}=await call;if(error){console.error("event-admin db",error.code||"error");throw new HttpError("database_error",500)}return data as T;
}
type Staff={rank:string;permissions:Record<string,boolean>;enabled:boolean;is_owner:boolean};
async function authorize(req:Request,alliance:string):Promise<Staff>{
 const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/i,"").trim();
 if(!token)throw new HttpError("authentication_required",401);
 const {data:{user},error}=await auth.auth.getUser(token);
 if(error||!user||user.is_anonymous)throw new HttpError("invalid_session",401);
 const staff=await checked<any>(db.from("aos_staff").select("rank,permissions,enabled")
 .eq("alliance_code",alliance).eq("user_id",user.id).maybeSingle());
 if(!staff?.enabled||!["R4","R5"].includes(staff.rank))throw new HttpError("not_authorized",403);
 staff.is_owner=staff.rank==="R5"&&user.email?.toLowerCase()==="admin@nap-tracker.invalid";
 const match=/^leader-([0-9]{5,20})@accounts\.allianceos\.invalid$/i.exec(user.email||"");
 if(match){
   const member=await checked<any>(db.from("players").select("alliance_rank,active")
    .eq("alliance_code",alliance).eq("game_id",match[1]).maybeSingle());
   if(!member?.active||![4,5].includes(Number(member.alliance_rank)))throw new HttpError("leader_no_longer_active",403);
   staff.rank="R"+member.alliance_rank;
 }
 if(!staff.is_owner&&!staff.permissions?.event_bot)
  throw new HttpError("permission_denied",403);
 return staff;
}
const can=(staff:Staff,perm:string)=>staff.is_owner||staff.permissions?.[perm]===true;
const validId=(s:unknown)=>typeof s==="string"&&/^[0-9]{17,20}$/.test(s);
async function getStatus(req:Request,alliance:string,staff:Staff,u:URL){
 const [global,local,heart,config,cycles,manualEvents,rules,history,nextJobs]=await Promise.all([
  checked<any>(db.from("aos_event_bot_settings")
   .select("sending_enabled,production_approved,role_mentions_enabled").eq("id",1).single()),
  checked<any>(db.from("aos_event_bot_alliance_state")
   .select("sending_enabled,role_mentions_enabled").eq("alliance_code",alliance).maybeSingle()),
  checked<any>(db.from("aos_event_bot_heartbeat").select("*").eq("id",1).maybeSingle()),
  checked<any>(db.from("aos_discord_bot_config").select("guild_id,channels").eq("alliance_code",alliance).maybeSingle()),
  checked<any[]>(db.from("aos_event_cycles").select("group_key,anchor_date,interval_days,duration_days,enabled,override_schedule")
   .eq("alliance_code",alliance).limit(400)),
  checked<any[]>(db.from("aos_events").select("id,status").eq("alliance_code",alliance)
   .eq("status","published").limit(300)),
  checked<any[]>(db.from("aos_discord_message_rules").select("id,event_key,title,day_number,trigger_type,enabled,messages,mention_role")
   .eq("alliance_code",alliance).limit(2000)),
  checked<any[]>(db.from("aos_event_bot_outbox")
   .select("id,rule_id,event_key,occurrence_date,event_day,language,scheduled_at,sent_at,channel_id,discord_message_id,status,attempts,error_code,error_detail")
   .eq("alliance_code",alliance).order("scheduled_at",{ascending:false}).limit(500)),
  checked<any[]>(db.from("aos_event_bot_outbox")
   .select("id,rule_id,event_key,occurrence_date,event_day,language,scheduled_at,sent_at,channel_id,discord_message_id,status,attempts,error_code,error_detail")
   .eq("alliance_code",alliance)
   .gte("scheduled_at",new Date(Date.now()-10*60000).toISOString())
   .order("scheduled_at",{ascending:true}).limit(350))
 ]);
 const state=local||{sending_enabled:false,role_mentions_enabled:false};
 const active=rules.filter(r=>r.enabled);
 const preview=nextJobs.slice(0,350);
 const cycleNames=new Set(cycles.filter(c=>c.enabled&&c.override_schedule===true).map(c=>c.group_key));
 for(const e of manualEvents)cycleNames.add("custom-"+e.id);
 const warn=active.filter(r=>!cycleNames.has(r.event_key)||!preview.some(p=>p.rule_id===r.id&&p.status!=="cancelled"))
  .map(r=>({id:r.id,event_key:r.event_key,event_day:r.day_number,
   reason:!cycleNames.has(r.event_key)?"Kein bestätigter Eventdurchlauf gespeichert":"Nicht planbar – Eventdatum oder Uhrzeit fehlt."}));
 const token=Deno.env.get("ALLIANCE_EVENT_DISCORD_TOKEN");
 let connected=false,botProblem=token?"discord_not_verified":"discord_token_missing";
 if(token){
  try{const d=await fetch("https://discord.com/api/v10/users/@me",{
   headers:{authorization:"Bot "+token},signal:AbortSignal.timeout(4000)});
   connected=d.ok;botProblem=d.ok?"":("discord_http_"+d.status);
  }catch{botProblem="discord_api_unreachable"}
 }
 const counts=Object.fromEntries(["planned","sent","failed","uncertain","skipped","cancelled","sending"]
 .map(s=>[s,history.filter(j=>j.status===s).length]));
 return response(req,{ok:true,alliance,global,local:state,heartbeat:heart,connected,botProblem,
  config:config||{},preview,warnings:warn,counts,history:history.slice(0,150),
  roleRules:rules.filter(r=>r.enabled).map(r=>({id:r.id,title:r.title,event_key:r.event_key,event_day:r.day_number,mention_role:r.mention_role})),
  canManage:can(staff,"event_bot"),canEvents:can(staff,"event_bot"),isOwner:staff.is_owner});
}
async function sendTest(req:Request,alliance:string,lang:string){
 if(!["de","en","fr"].includes(lang))throw new HttpError("invalid_language");
 const config=await checked<any>(db.from("aos_discord_bot_config").select("guild_id,channels")
  .eq("alliance_code",alliance).maybeSingle());
 const channel=config?.channels?.[lang];
 if(!validId(channel)||!validId(config?.guild_id))throw new HttpError("discord_channel_not_configured");
 const token=Deno.env.get("ALLIANCE_EVENT_DISCORD_TOKEN");
 if(!token)throw new HttpError("discord_token_missing",503);
 const get=await fetch("https://discord.com/api/v10/channels/"+channel,{
  headers:{authorization:"Bot "+token},signal:AbortSignal.timeout(9000)});
 if(!get.ok)throw new HttpError("discord_channel_check_"+get.status,502);
 const ch=await get.json();
 if(ch.guild_id!==config.guild_id)throw new HttpError("discord_guild_mismatch");
 const localized:any={de:"Dies ist eine Testnachricht des AllianceOS Event-Bots. Kein geplanter Eventversand.",
 en:"This is an AllianceOS Event Bot test message. It is not a scheduled event announcement.",
 fr:"Ceci est un message de test du bot événementiel AllianceOS. Ce n'est pas une annonce programmée."};
 const sent=await fetch("https://discord.com/api/v10/channels/"+channel+"/messages",{
  method:"POST",headers:{authorization:"Bot "+token,"content-type":"application/json"},
  body:JSON.stringify({content:"🧪 [AllianceOS TEST]\n"+localized[lang],allowed_mentions:{parse:[]}}),
  signal:AbortSignal.timeout(12500)
 });
 if(!sent.ok)throw new HttpError("discord_test_http_"+sent.status,502);
 const data=await sent.json();
 return {message_id:String(data.id),channel_id:channel,language:lang};
}
Deno.serve(async(req:Request)=>{
 try{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:headers(req)});
  if(req.method!=="GET"&&req.method!=="POST")throw new HttpError("method_not_allowed",405);
  const u=new URL(req.url),alliance=String(u.searchParams.get("alliance")||"").trim();
  if(!/^[A-Za-z0-9_-]{2,16}$/.test(alliance))throw new HttpError("invalid_alliance");
  const staff=await authorize(req,alliance);
  if(req.method==="GET")return await getStatus(req,alliance,staff,u);
  const body=await req.json().catch(()=>{throw new HttpError("invalid_json")});
  if(body.action==="test"){
   if(!can(staff,"event_bot"))throw new HttpError("permission_denied",403);
   return response(req,{ok:true,...await sendTest(req,alliance,body.language)});
  }
  if(body.action==="set_alliance"){
   if(!can(staff,"event_bot"))throw new HttpError("permission_denied",403);
   const item=await checked(db.from("aos_event_bot_alliance_state").upsert({
    alliance_code:alliance,sending_enabled:body.enabled===true,updated_at:new Date().toISOString()
   },{onConflict:"alliance_code"}).select("sending_enabled").single());
   return response(req,{ok:true,local:item});
  }
  if(body.action==="pause_global"){
   if(!staff.is_owner)throw new HttpError("permission_denied",403);
   await checked(db.from("aos_event_bot_settings").update({sending_enabled:false,updated_at:new Date().toISOString()}).eq("id",1));
   return response(req,{ok:true,paused:true});
  }
  if(body.action==="set_rule_mention"){
   if(!can(staff,"event_bot"))throw new HttpError("permission_denied",403);
   if(!/^[0-9a-f-]{36}$/i.test(body.rule_id||""))throw new HttpError("invalid_rule_id");
   const rule=await checked(db.from("aos_discord_message_rules")
    .update({mention_role:body.enabled===true}).eq("id",body.rule_id)
    .eq("alliance_code",alliance).select("id,mention_role").maybeSingle());
   if(!rule)throw new HttpError("rule_not_found",404);
   return response(req,{ok:true,rule});
  }
  if(body.action==="set_global_mentions"){
   if(!staff.is_owner)throw new HttpError("permission_denied",403);
   const global=await checked<any>(db.from("aos_event_bot_settings")
    .select("production_approved").eq("id",1).single());
   if(body.enabled===true&&!global.production_approved)throw new HttpError("production_approval_required",403);
   const item=await checked(db.from("aos_event_bot_settings").update({
    role_mentions_enabled:body.enabled===true,updated_at:new Date().toISOString()
   }).eq("id",1).select("role_mentions_enabled").single());
   return response(req,{ok:true,global:item});
  }
  if(body.action==="set_alliance_mentions"){
   if(!can(staff,"event_bot"))throw new HttpError("permission_denied",403);
   const item=await checked(db.from("aos_event_bot_alliance_state").upsert({
     alliance_code:alliance,role_mentions_enabled:body.enabled===true,updated_at:new Date().toISOString()
   },{onConflict:"alliance_code"}).select("role_mentions_enabled").single());
   return response(req,{ok:true,local:item});
  }
  throw new HttpError("unknown_action");
 }catch(e){
  const code=e instanceof HttpError?e.code:"internal_error";
  const status=e instanceof HttpError?e.status:500;
  if(status===500)console.error("event-bot-admin",String(e));
  return response(req,{error:code},status);
 }
});
