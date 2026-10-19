# AllianceOS Event Bot — Operations & rollout

## Current state (2026-10-19)
- **NOT LIVE FOR REGULAR EVENT DELIVERY.** Production release gate, global dispatcher, NRW and all role pings are disabled.
- SQL outbox/schema deployed to existing Supabase `bdzlgirowutasrsycjfj`.
- `alliance-event-bot-dispatch` Edge Function ACTIVE, invoked by `alliance-event-bot-dispatch-1m` Cron, 1-minute cadence.
- `alliance-event-bot-admin` Edge Function ACTIVE, restricted to verified AllianceOS R4/R5 with permissioned alliance scope.
- Leadership frontend additions live **only in GitHub branch `feature/alliance-event-bot`**, not on Vercel production and not on the current GitHub Pages test site.
- Discord bot token is **not configured**. No live Discord event messages were sent.

## Architecture & authorities
- Edit content, DE/EN/FR channels, day number and UTC times **only** in the existing AllianceOS Leadership Discord Event Bot UI (`Boltotelli/welcome-nrw`).
- Time source A: explicitly saved/enabled `aos_event_cycles` (`override_schedule=true`) and day-specific `aos_discord_event_day_times`, then `aos_discord_event_anchors` or cycle start for day 1. The frontend's unsaved default cycle is **not enough**. A recurring group with an unconfirmed cycle is not scheduled.
- Time source B: manually created **published** `aos_events`, with rule keys `custom-<event_uuid>` and optional day-specific times. Draft/cancelled manual events cannot send.
- The existing public Dashboard's local rhythm and dates cannot be pulled server-side from its browser-only JS by cron: where no saved authoritative cycle/manual occurrence exists, no send is created. Never extrapolate or insert default dates.
- Locales: `de`, `en`, `fr` each strictly use their own message and their matching configured channel. `es` is reserved but never dispatched without UI support.
- Onboarding language-role IDs may be read only from `alliance_discord_config.language_role_ids`; no member/role changes. Three-layer consent: message flag + alliance flag + global flag, all false by default. Discord `allowed_mentions` blocks everyone, here, users and arbitrary roles.
- Idempotent key: alliance+event+occurrence_start_date+event_day+rule_id+language.
- Two-phase reliability: atomically reserve with `SKIP LOCKED`, record per-language Discord Message ID and send state. Uncertain POSTs are **not retried automatically**, because the Discord message might already have been created. Inspect Discord and log before manual recovery. Discord errors marked permanent stop retrying; 429 retries with delay, max 5 attempts. May require manual reconciliation for uncertain operations.

## One-time Discord setup (only when ready)
1. Go to Discord Developer Portal, create an Application and Bot (if not already made). Leave privileged Gateway intents OFF; this bot makes REST outbound calls and does not require a constantly connected Gateway session.
2. Add the bot to the desired Discord server using OAuth2 bot scope and **View Channels + Send Messages**, restrict permissions to the intended DE/EN/FR channels. Do **not** grant Administrator, Manage Roles, Mention Everyone, or Message Content intent. A permitted existing language-role mention may require granting Discord's `Mention @everyone, @here, and All Roles` permission if the relevant language role is not mentionable; safer is to make the role mentionable only when the owner requests pings.
3. In **Supabase Dashboard → Project → Edge Functions → Secrets**, store the bot token as `ALLIANCE_EVENT_DISCORD_TOKEN`. Never post it in GitHub, chat or browser-side configuration. Supabase automatically supplies service role and URL to functions.
4. Enter your Discord server ID and each destination channel ID in the existing AllianceOS Leitung → Discord Event Bot page. Confirm at least one event cycle and UTC start/day-times, fill three translations, and activate the rule. Still no regular sending.
5. Test with the **Testnachricht senden** button in the Leadership *staging branch* once it is deployed. It sends a clearly labelled standalone test and never marks a scheduled job as sent.
6. Do not enable until the user explicitly approves. Approval consists of separate controlled updates to `aos_event_bot_settings.production_approved`, `aos_event_bot_settings.sending_enabled`, and `aos_event_bot_alliance_state.sending_enabled` for the target alliance. These values must remain OFF now.

## Rollout safety
- GitHub Actions / Vercel production may deploy upon pushing `welcome-nrw/main`. Do not merge the UI branch or update Vercel without explicit permission.
- No edits to the existing NAP Tracker, onboarding bot, Bear Buff/ministers, or external pipelines.
- Global kill switch and alliance pause implemented in secured admin API. Pause **does not** backfill messages later; overdue items become skipped. A separate hard production-approval gate prevents accidental dispatch despite toggles.
- New tables use RLS, no access to anon/authenticated, service-role access from Edge Functions only.
- Run `tests/dispatch_regression.sql` through privileged SQL after backing up if making schedule changes. The regression suite is transactional and rolls back fixtures.
- If no channel is configured or cycle date/time is confirmed, the UI must display **Nicht planbar – Eventdatum oder Uhrzeit fehlt.**
- A failed or uncertain send is recorded with attempts/error and should be inspected by an R4/R5; the bot does not silently publish to another channel.
- Historical unrelated Supabase RLS advisories exist. Investigate separately; this project does not change them without an impact review.

## Smoke-check SQL (no secrets shown)
```sql
SELECT sending_enabled, production_approved, role_mentions_enabled FROM public.aos_event_bot_settings WHERE id=1;
SELECT alliance_code,sending_enabled,role_mentions_enabled FROM public.aos_event_bot_alliance_state;
SELECT last_check,last_success,last_error,dispatcher_version FROM public.aos_event_bot_heartbeat WHERE id=1;
SELECT event_key,event_day,language,scheduled_at,status,error_code FROM public.aos_event_bot_outbox ORDER BY created_at DESC LIMIT 30;
SELECT jobname,active,schedule FROM cron.job WHERE jobname='alliance-event-bot-dispatch-1m';
```
