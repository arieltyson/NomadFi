CREATE TABLE nomadfi.fibot_profiles (
  user_id uuid PRIMARY KEY REFERENCES nomadfi.users(id) ON DELETE CASCADE,
  revision bigint NOT NULL DEFAULT 1,
  bank_revision bigint NOT NULL DEFAULT 0,
  confirmed_bank_revision bigint NOT NULL DEFAULT 0,
  worker_lock boolean NOT NULL DEFAULT false,
  context jsonb NOT NULL,
  policy jsonb NOT NULL,
  settings jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (octet_length(context::text) <= 131072)
);
CREATE TABLE nomadfi.fibot_jobs (
  user_id uuid PRIMARY KEY REFERENCES nomadfi.fibot_profiles(user_id) ON DELETE CASCADE,
  requested_revision bigint NOT NULL DEFAULT 1,
  completed_revision bigint NOT NULL DEFAULT 0,
  lease_epoch bigint NOT NULL DEFAULT 0,
  lease_expires_at timestamptz,
  available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  attempts integer NOT NULL DEFAULT 0,
  dead_letter boolean NOT NULL DEFAULT false
);
CREATE TABLE nomadfi.fibot_alerts (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES nomadfi.fibot_profiles(user_id) ON DELETE CASCADE,
  profile_revision bigint NOT NULL,
  bank_revision bigint NOT NULL,
  category text NOT NULL CHECK (category IN ('cash_shortfall', 'stale_context')),
  fingerprint text NOT NULL,
  decision jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded boolean NOT NULL DEFAULT false,
  dismissed_at timestamptz,
  notification_at timestamptz,
  UNIQUE (user_id, fingerprint)
);
CREATE INDEX fibot_pending ON nomadfi.fibot_jobs(available_at) WHERE NOT dead_letter;
CREATE VIEW nomadfi.fibot_connections AS
  SELECT c.id, c.user_id, c.state, c.last_synced_at FROM nomadfi.connections c
    JOIN nomadfi.fibot_profiles p ON p.user_id = c.user_id;

CREATE FUNCTION nomadfi.stop_fibot_on_deletion() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.state = 'deleting' THEN DELETE FROM nomadfi.fibot_profiles WHERE user_id = NEW.id; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER stop_fibot_on_deletion AFTER UPDATE OF state ON nomadfi.users
  FOR EACH ROW EXECUTE FUNCTION nomadfi.stop_fibot_on_deletion();
REVOKE ALL ON FUNCTION nomadfi.stop_fibot_on_deletion() FROM PUBLIC;
