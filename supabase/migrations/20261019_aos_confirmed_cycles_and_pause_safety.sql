-- Only leader-confirmed cycles may create jobs. UTC calendar arithmetic and pause catch-up safety.
create or replace function public.aos_event_bot_refresh()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_scan timestamptz := clock_timestamp(); v_count integer := 0;
begin
 perform pg_advisory_xact_lock(76010788);
 with base as (
 select r.id rule_id,r.alliance_code,r.event_key,r.day_number,r.trigger_type,r.relative_to,
  r.offset_minutes,r.clock_utc,r.messages,r.mention_role,
  c.anchor_date,c.interval_days,c.duration_days,c.start_time_utc cycle_start,
  cfg.guild_id,cfg.channels,
  st.role_mentions_enabled alliance_mentions,
  gs.role_mentions_enabled global_mentions,
  onboard.language_role_ids,
  (c.anchor_date + ((n.i * c.interval_days) * interval '1 day'))::date occurrence_date
 from public.aos_discord_message_rules r
 join public.aos_event_cycles c on c.alliance_code=r.alliance_code and c.group_key=r.event_key
 join public.aos_discord_bot_config cfg on cfg.alliance_code=r.alliance_code
 join public.aos_event_bot_alliance_state st on st.alliance_code=r.alliance_code
 cross join public.aos_event_bot_settings gs
 left join public.alliance_discord_config onboard
   on onboard.alliance_code=r.alliance_code and onboard.guild_id=cfg.guild_id and onboard.active
 cross join lateral generate_series(
   greatest(0, (((now() at time zone 'UTC')::date-c.anchor_date-3)/c.interval_days)),
   greatest(0, (((now() at time zone 'UTC')::date-c.anchor_date+45)/c.interval_days))
 ) n(i)
 where r.enabled and c.enabled and c.override_schedule=true and c.interval_days>0
  and r.day_number between 1 and c.duration_days
  and cfg.guild_id ~ '^[0-9]{17,20}$'
 ),
 dates as (
 select b.*, (b.occurrence_date+(b.day_number-1))::date event_date,
  a.start_time_utc legacy_start, a.end_time_utc legacy_end,
  dt.start_time_utc day_start,dt.end_time_utc day_end
 from base b
 left join public.aos_discord_event_anchors a on a.alliance_code=b.alliance_code and a.event_key=b.event_key
 left join public.aos_discord_event_day_times dt
   on dt.alliance_code=b.alliance_code and dt.event_key=b.event_key and dt.day_number=b.day_number
 where b.occurrence_date >= (now() at time zone 'UTC')::date-3 and b.occurrence_date <= (now() at time zone 'UTC')::date+45
 ),
 anchored as (
 select d.*,
 coalesce(d.day_start,case when d.day_number=1 then d.legacy_start end,
   case when d.day_number=1 then d.cycle_start end) start_utc,
 coalesce(d.day_end,case when d.day_number=1 then d.legacy_end end) end_utc
 from dates d
 ),
 translations as (
 select a.*,l.lang,trim(a.messages->>l.lang) msg,
   trim(coalesce(a.channels->>l.lang,'')) channel,
   case when a.mention_role and a.alliance_mentions and a.global_mentions
     then a.language_role_ids->>l.lang else null end role
 from anchored a cross join (values('de'),('en'),('fr')) l(lang)
 ),
 candidates as (
 select t.*,
  case when t.trigger_type='clock' and t.clock_utc is not null
    then (t.event_date+t.clock_utc) at time zone 'UTC'
   when t.trigger_type='relative' and t.relative_to='start' and t.start_utc is not null
    then ((t.event_date+t.start_utc) at time zone 'UTC') + (t.offset_minutes * interval '1 minute')
   when t.trigger_type='relative' and t.relative_to='end' and t.end_utc is not null
    then ((t.event_date+t.end_utc) at time zone 'UTC')
      + (case when t.start_utc is not null and t.end_utc < t.start_utc then interval '1 day'
          else interval '0 day' end)
      + (t.offset_minutes * interval '1 minute')
   else null end due
 from translations t
 where nullif(t.msg,'') is not null and char_length(t.msg) <=2000
   and t.channel ~ '^[0-9]{17,20}$'
 )
 insert into public.aos_event_bot_outbox
 (alliance_code,event_key,occurrence_date,event_day,rule_id,language,
  scheduled_at,guild_id,channel_id,role_id,content,last_seen_at)
 select alliance_code,event_key,occurrence_date,day_number,rule_id,lang,
    due,guild_id,channel,role,msg,v_scan
 from candidates where due is not null
 on conflict (alliance_code,event_key,occurrence_date,event_day,rule_id,language)
 do update set
 scheduled_at=excluded.scheduled_at,guild_id=excluded.guild_id,
 channel_id=excluded.channel_id,role_id=excluded.role_id,
 content=excluded.content,last_seen_at=excluded.last_seen_at,
 updated_at=now()
 where public.aos_event_bot_outbox.status in ('planned','failed');
 get diagnostics v_count=row_count;
 -- Obsolete rules / changed dates / disabled events never dispatch.
 update public.aos_event_bot_outbox set status='cancelled',updated_at=now(),error_code='configuration_changed'
 where status in ('planned','failed') and last_seen_at<v_scan;
 -- Stale messages are skipped, not sent after an outage or pause.
 update public.aos_event_bot_outbox set status='skipped',updated_at=now(),error_code='past_grace_window'
 where status in ('planned','failed') and scheduled_at<now()-interval '10 minutes';
 -- Paused or not-yet-approved slots are skipped immediately when due.
 -- This prevents silent catch-up sends after a pause (including pauses under ten minutes).
 update public.aos_event_bot_outbox o
 set status='skipped',updated_at=now(),error_code='paused_when_due'
 where o.status in ('planned','failed') and o.scheduled_at<=now()
   and not exists (
    select 1 from public.aos_event_bot_settings gs
    join public.aos_event_bot_alliance_state st on st.alliance_code=o.alliance_code
    where gs.id=1 and gs.sending_enabled and gs.production_approved and st.sending_enabled
   );
 return v_count;
end $$;
