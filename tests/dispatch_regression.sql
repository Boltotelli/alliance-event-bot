-- Run once with a privileged SQL editor. The entire test rolls back its fixtures.
BEGIN;
INSERT INTO public.aos_alliances(code,name,kingdom_id) VALUES ('ZTEST','Event Bot Regression',9999);
INSERT INTO public.aos_event_bot_alliance_state(alliance_code,sending_enabled)
VALUES ('NRW',false),('ZTEST',false) ON CONFLICT(alliance_code) DO UPDATE SET sending_enabled=false;
INSERT INTO public.aos_discord_bot_config(alliance_code,guild_id,channels)
VALUES ('NRW','123456789012345678','{"de":"123456789012345679","en":"123456789012345680","fr":"123456789012345681"}'),
 ('ZTEST','123456789012345682','{"de":"123456789012345683","en":"123456789012345684","fr":"123456789012345685"}')
ON CONFLICT(alliance_code) DO UPDATE SET guild_id=excluded.guild_id,channels=excluded.channels;
INSERT INTO public.aos_event_cycles(alliance_code,group_key,anchor_date,interval_days,duration_days,phase_count,enabled,override_schedule)
SELECT code,'fixture-calendar',((now() at time zone 'UTC')::date+5),28,7,7,true,true
FROM (VALUES('NRW'),('ZTEST')) v(code);
INSERT INTO public.aos_discord_event_day_times(alliance_code,event_key,day_number,start_time_utc)
VALUES('NRW','fixture-calendar',3,'00:00'),('ZTEST','fixture-calendar',3,'00:00');
INSERT INTO public.aos_discord_message_rules(id,alliance_code,event_key,title,trigger_type,relative_to,offset_minutes,clock_utc,day_number,enabled,messages)
VALUES
 ('00000000-0000-4000-8000-000000000011','NRW','fixture-calendar','Day3 reminder','relative','start',-10,null,3,true,'{"de":"Deutsch","en":"English","fr":"Francais"}'),
 ('00000000-0000-4000-8000-000000000012','NRW','fixture-calendar','Day4 fixed','clock','start',0,'16:00',4,true,'{"de":"Deutsch","en":"English","fr":"Francais"}'),
 ('00000000-0000-4000-8000-000000000013','ZTEST','fixture-calendar','Day3 reminder','relative','start',-10,null,3,true,'{"de":"Deutsch","en":"English","fr":"Francais"}');
SELECT public.aos_event_bot_refresh() AS cycle_jobs;
DO $assert$
DECLARE n int; due timestamptz; anchor date := (now() at time zone 'UTC')::date+5;
BEGIN
 SELECT count(*),min(scheduled_at) INTO n,due FROM public.aos_event_bot_outbox
 WHERE rule_id='00000000-0000-4000-8000-000000000011' AND occurrence_date=anchor;
 IF n<>3 THEN RAISE EXCEPTION '3-language fan-out failed: %',n;END IF;
 IF due <> ((anchor+1)::timestamp + time '23:50') at time zone 'UTC'
 THEN RAISE EXCEPTION 'cross-midnight UTC failed: %',due;END IF;
 SELECT min(scheduled_at) INTO due FROM public.aos_event_bot_outbox
 WHERE rule_id='00000000-0000-4000-8000-000000000012' AND occurrence_date=anchor;
 IF due <> ((anchor+3)::date + time '16:00') at time zone 'UTC'
 THEN RAISE EXCEPTION 'fixed day4 clock failed: %',due;END IF;
 IF (SELECT count(*) FROM public.aos_event_bot_claim(20))<>0
 THEN RAISE EXCEPTION 'claimed a message while globally disabled';END IF;
END $assert$;
SELECT public.aos_event_bot_refresh() AS idempotent_cycle_jobs;
DO $assert$ DECLARE n int;BEGIN
 SELECT count(*) INTO n FROM public.aos_event_bot_outbox
 WHERE rule_id='00000000-0000-4000-8000-000000000011';
 IF n<>3 THEN RAISE EXCEPTION 'duplicate run: %',n;END IF;END $assert$;
UPDATE public.aos_event_bot_outbox SET status='sent',discord_message_id='fixture-sent'
WHERE rule_id='00000000-0000-4000-8000-000000000011' AND language='de';
UPDATE public.aos_discord_event_day_times SET start_time_utc='01:00'
WHERE alliance_code='NRW' AND event_key='fixture-calendar' AND day_number=3;
SELECT public.aos_event_bot_refresh() AS rescheduled_jobs;
DO $assert$ DECLARE old_due timestamptz; new_due timestamptz;anchor date:=(now() at time zone 'UTC')::date+5;BEGIN
 SELECT scheduled_at INTO old_due FROM aos_event_bot_outbox
 WHERE rule_id='00000000-0000-4000-8000-000000000011' AND language='de' AND occurrence_date=anchor;
 SELECT scheduled_at INTO new_due FROM aos_event_bot_outbox
 WHERE rule_id='00000000-0000-4000-8000-000000000011' AND language='en' AND occurrence_date=anchor;
 IF old_due<>((anchor+1)::date+time '23:50') at time zone 'UTC' OR
   new_due<>((anchor+2)::date+time '00:50') at time zone 'UTC' THEN
  RAISE EXCEPTION 'rescheduling sent/unsent failed: % / %',old_due,new_due;END IF;
 IF (SELECT channel_id FROM aos_event_bot_outbox
 WHERE rule_id='00000000-0000-4000-8000-000000000013' AND language='en' ORDER BY scheduled_at LIMIT 1)
  <>'123456789012345684' THEN RAISE EXCEPTION 'cross-alliance channel leak';END IF;
END $assert$;
UPDATE public.aos_discord_message_rules SET enabled=false WHERE id='00000000-0000-4000-8000-000000000011';
SELECT public.aos_event_bot_refresh() AS cancelled_jobs;
DO $assert$ DECLARE n int;BEGIN
 SELECT count(*) INTO n FROM public.aos_event_bot_outbox
 WHERE rule_id='00000000-0000-4000-8000-000000000011' AND status='cancelled';
 IF n<>2 THEN RAISE EXCEPTION 'cancel disabled pending records: %',n;END IF;
 IF NOT EXISTS(SELECT 1 FROM public.aos_event_bot_outbox WHERE
  rule_id='00000000-0000-4000-8000-000000000011' AND language='de' AND status='sent')
 THEN RAISE EXCEPTION 'previously sent message modified';END IF;
END $assert$;
INSERT INTO public.aos_events(id,alliance_code,title,start_at,end_at,status)
VALUES('00000000-0000-4000-8000-000000000019','NRW','{"de":"Manual Test"}',
 (((now() at time zone 'UTC')::date+9)+time '19:00') at time zone 'UTC',
 (((now() at time zone 'UTC')::date+11)+time '20:00') at time zone 'UTC','published');
INSERT INTO public.aos_discord_message_rules
(id,alliance_code,event_key,title,trigger_type,relative_to,offset_minutes,day_number,enabled,messages)
VALUES('00000000-0000-4000-8000-000000000014','NRW',
 'custom-00000000-0000-4000-8000-000000000019','Manual day2',
 'relative','start',-15,2,true,'{"de":"Deutsch","en":"English","fr":"Francais"}');
INSERT INTO public.aos_discord_event_day_times(alliance_code,event_key,day_number,start_time_utc)
VALUES('NRW','custom-00000000-0000-4000-8000-000000000019',2,'00:00');
SELECT public.aos_event_bot_refresh_manual() AS published_manual_jobs;
SELECT public.aos_event_bot_refresh() AS cycle_reconciliation;
SELECT public.aos_event_bot_refresh_manual() AS manual_reconciliation;
DO $assert$ DECLARE n int;due timestamptz;anchor date:=(now() at time zone 'UTC')::date+9;BEGIN
 SELECT count(*),min(scheduled_at) INTO n,due FROM aos_event_bot_outbox WHERE
 rule_id='00000000-0000-4000-8000-000000000014' AND status='planned';
 IF n<>3 THEN RAISE EXCEPTION 'published manual entries cancelled: %',n;END IF;
 IF due <> ((anchor)::date+time '23:45') at time zone 'UTC'
 THEN RAISE EXCEPTION 'manual UTC date failed: %',due;END IF;
END $assert$;
ROLLBACK;