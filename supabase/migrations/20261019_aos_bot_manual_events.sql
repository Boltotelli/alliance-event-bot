
-- Use existing published AllianceOS manual events as another confirmed source.
-- This is NOT an event editor and does not replicate the event calendar.
alter table public.aos_event_bot_outbox
 add column if not exists source_type text not null default 'cycle'
 check (source_type in ('cycle','manual'));
create or replace function public.aos_event_bot_refresh_manual()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_scan timestamptz := clock_timestamp(); v_count integer := 0;
begin
 perform pg_advisory_xact_lock(76010789);
 with manual as (
 select e.alliance_code,('custom-'||e.id::text) as event_key,
 e.start_at,e.end_at,r.id rule_id,r.day_number,r.trigger_type,r.relative_to,
 r.offset_minutes,r.clock_utc,r.messages,r.mention_role,
 cfg.guild_id,cfg.channels,
 st.role_mentions_enabled alliance_mentions,gs.role_mentions_enabled global_mentions,
 onboard.language_role_ids,
 ((e.start_at at time zone 'UTC')::date + (r.day_number-1))::date event_date
 from public.aos_events e
 join public.aos_discord_message_rules r on r.alliance_code=e.alliance_code
  and r.event_key=('custom-'||e.id::text) and r.enabled
 join public.aos_discord_bot_config cfg on cfg.alliance_code=e.alliance_code
 join public.aos_event_bot_alliance_state st on st.alliance_code=e.alliance_code
 cross join public.aos_event_bot_settings gs
 left join public.alliance_discord_config onboard on
  onboard.alliance_code=e.alliance_code and onboard.guild_id=cfg.guild_id and onboard.active
 where e.status='published'
  and cfg.guild_id ~ '^[0-9]{17,20}$'
  and (e.start_at at time zone 'UTC')::date between (now() at time zone 'UTC')::date-3 and (now() at time zone 'UTC')::date+45
  and r.day_number between 1 and 14
 ),
 dated as (
 select m.*,
 coalesce(dt.start_time_utc,
   case when m.day_number=1 then a.start_time_utc end,
   case when m.day_number=1 then (m.start_at at time zone 'UTC')::time end) start_utc,
 coalesce(dt.end_time_utc,
   case when m.day_number=1 then a.end_time_utc end,
   case when m.event_date=(coalesce(m.end_at,m.start_at) at time zone 'UTC')::date
    then (coalesce(m.end_at,m.start_at) at time zone 'UTC')::time end) end_utc
 from manual m
 left join public.aos_discord_event_day_times dt on dt.alliance_code=m.alliance_code
  and dt.event_key=m.event_key and dt.day_number=m.day_number
 left join public.aos_discord_event_anchors a on a.alliance_code=m.alliance_code and a.event_key=m.event_key
 where m.event_date <= (coalesce(m.end_at,m.start_at) at time zone 'UTC')::date
 ),
 languages as (
 select d.*,l.lang,trim(d.messages->>l.lang) msg,trim(coalesce(d.channels->>l.lang,'')) channel,
 case when d.mention_role and d.alliance_mentions and d.global_mentions
  then d.language_role_ids->>l.lang else null end role
 from dated d cross join (values('de'),('en'),('fr')) l(lang)
 ),
 resolved as (
 select l.*,
  case when l.trigger_type='clock' and l.clock_utc is not null
    then (l.event_date+l.clock_utc) at time zone 'UTC'
   when l.trigger_type='relative' and l.relative_to='start' and l.start_utc is not null
    then ((l.event_date+l.start_utc) at time zone 'UTC')+(l.offset_minutes*interval '1 minute')
   when l.trigger_type='relative' and l.relative_to='end' and l.end_utc is not null
    then ((l.event_date+l.end_utc) at time zone 'UTC')
      +(case when l.start_utc is not null and l.end_utc < l.start_utc then interval '1 day' else interval '0 day' end)
      +(l.offset_minutes*interval '1 minute')
   else null end due
 from languages l
 where nullif(l.msg,'') is not null and char_length(l.msg)<=2000
 and l.channel ~ '^[0-9]{17,20}$'
 )
 insert into public.aos_event_bot_outbox
 (alliance_code,event_key,occurrence_date,event_day,rule_id,language,
  scheduled_at,guild_id,channel_id,role_id,content,source_type,last_seen_at)
 select alliance_code,event_key,(start_at at time zone 'UTC')::date,day_number,rule_id,lang,
  due,guild_id,channel,role,msg,'manual',v_scan
 from resolved where due is not null
 on conflict(alliance_code,event_key,occurrence_date,event_day,rule_id,language)
 do update set scheduled_at=excluded.scheduled_at,guild_id=excluded.guild_id,
 channel_id=excluded.channel_id,role_id=excluded.role_id,content=excluded.content,
 last_seen_at=excluded.last_seen_at,updated_at=now()
 where public.aos_event_bot_outbox.status in ('planned','failed');
 get diagnostics v_count=row_count;
 update public.aos_event_bot_outbox set status='cancelled',updated_at=now(),error_code='configuration_changed'
 where status in ('planned','failed') and source_type='manual' and last_seen_at<v_scan;
 update public.aos_event_bot_outbox set status='skipped',updated_at=now(),error_code='past_grace_window'
 where status in ('planned','failed') and source_type='manual'
  and scheduled_at<now()-interval '10 minutes';
 update public.aos_event_bot_outbox o set status='skipped',updated_at=now(),error_code='paused_when_due'
 where o.source_type='manual' and o.status in ('planned','failed') and o.scheduled_at<=now()
  and not exists(
   select 1 from public.aos_event_bot_settings gs
   join public.aos_event_bot_alliance_state st on st.alliance_code=o.alliance_code
   where gs.id=1 and gs.sending_enabled and gs.production_approved and st.sending_enabled
  );
 return v_count;
end $$;
revoke all on function public.aos_event_bot_refresh_manual() from public,anon,authenticated;
grant execute on function public.aos_event_bot_refresh_manual() to service_role;
