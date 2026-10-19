# AllianceOS Discord Event Bot

Isolated bot service for AllianceOS. Reads existing `aos_discord_*` configuration, event cycles, and Discord onboarding language roles from the shared Supabase project (`bdzlgirowutasrsycjfj`).

**Safe by default:** production sending, alliance sending, and role mentions are all disabled until explicitly authorized. No Discord token belongs in this repository. Never publish production Vercel without permission.

## Integration
- Source of configuration: `Boltotelli/welcome-nrw` /leitung Event-Bot.
- Database: same Supabase project, only isolated `aos_event_bot_*` additions.
- Runtime: Supabase Edge Function + PostgreSQL scheduled job, without a separately hosted Discord gateway bot.
- Existing onboarding / Bear Buff / NAP bots are not modified.

See `docs/OPERATIONS.md` for rollout, risks, and first-run checklist.
