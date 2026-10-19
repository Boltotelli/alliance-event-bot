alter table public.aos_event_bot_settings
 add column if not exists production_approved boolean not null default false;
create or replace function public.aos_event_bot_is_approved()
returns boolean language sql security definer set search_path=public,pg_temp as $$
 select sending_enabled and production_approved from public.aos_event_bot_settings where id=1
$$;
revoke all on function public.aos_event_bot_is_approved() from public,anon,authenticated;
grant execute on function public.aos_event_bot_is_approved() to service_role;
