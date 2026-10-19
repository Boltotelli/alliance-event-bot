insert into public.aos_event_bot_alliance_state(alliance_code,sending_enabled,role_mentions_enabled)
values ('NRW',false,false) on conflict(alliance_code) do nothing;