-- One-time NRW pilot Discord test audit, atomically claimed by dispatcher.
CREATE TABLE IF NOT EXISTS public.aos_event_bot_setup_test (
  test_key text PRIMARY KEY,
  alliance_code text NOT NULL,
  language text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','attempted','sent','failed','uncertain')),
  discord_message_id text,
  channel_id text,
  error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.aos_event_bot_setup_test ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aos_event_bot_setup_test FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.aos_event_bot_setup_test TO service_role;
INSERT INTO public.aos_event_bot_setup_test(test_key,alliance_code,language,status)
VALUES('nrw-de-initial-20261019','NRW','de','pending')
ON CONFLICT(test_key) DO NOTHING;