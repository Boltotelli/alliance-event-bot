-- User-approved NRW-only role mentions per language. Spanish channel and message texts set by prior migration.
update public.aos_event_bot_settings set role_mentions_enabled=true,updated_at=now() where id=1 and production_approved;
update public.aos_event_bot_alliance_state set role_mentions_enabled=true,updated_at=now() where alliance_code='NRW' and sending_enabled;
update public.aos_discord_message_rules set mention_role=true where alliance_code='NRW';