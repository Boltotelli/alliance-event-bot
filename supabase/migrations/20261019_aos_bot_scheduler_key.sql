alter table public.aos_event_bot_settings
 add column if not exists scheduler_key text not null default gen_random_uuid()::text;
alter table public.aos_event_bot_heartbeat
 add column if not exists dispatcher_version text,
 add column if not exists last_processed integer not null default 0;
