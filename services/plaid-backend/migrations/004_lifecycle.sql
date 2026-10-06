CREATE TABLE nomadfi.link_attempts (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES nomadfi.users(id) ON DELETE CASCADE,
    environment text NOT NULL CHECK (environment IN ('sandbox', 'production')),
    state text NOT NULL DEFAULT 'created'
        CHECK (state IN ('created', 'exchanging', 'exchanged', 'complete', 'recovery_required')),
    public_digest bytea,
    public_key_id text,
    encrypted_public bytea,
    result_key_id text,
    encrypted_result bytea,
    lease_epoch bigint NOT NULL DEFAULT 0,
    lease_expires_at timestamptz,
    expires_at timestamptz NOT NULL DEFAULT clock_timestamp() + interval '4 hours',
    connection_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE nomadfi.revocation_jobs (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES nomadfi.users(id) ON DELETE CASCADE,
    purpose text NOT NULL CHECK (purpose IN ('plaid', 'apple')),
    resource_id uuid NOT NULL,
    attempts integer NOT NULL DEFAULT 0,
    lease_epoch bigint NOT NULL DEFAULT 0,
    lease_expires_at timestamptz,
    available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    completed_at timestamptz,
    dead_letter boolean NOT NULL DEFAULT false,
    UNIQUE (purpose, resource_id)
);

CREATE TABLE nomadfi.snapshots (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES nomadfi.users(id) ON DELETE CASCADE,
    revision bigint NOT NULL,
    expires_at timestamptz NOT NULL DEFAULT clock_timestamp() + interval '1 hour'
);
CREATE TABLE nomadfi.snapshot_records (
    snapshot_id uuid NOT NULL REFERENCES nomadfi.snapshots(id) ON DELETE CASCADE,
    ordinal bigint NOT NULL,
    connection_id uuid NOT NULL,
    kind text NOT NULL,
    external_id text NOT NULL,
    payload jsonb NOT NULL,
    removed boolean NOT NULL,
    PRIMARY KEY (snapshot_id, ordinal)
);

CREATE TABLE nomadfi.rate_windows (
    key_hash bytea PRIMARY KEY,
    window_at timestamptz NOT NULL,
    count integer NOT NULL
);
REVOKE ALL ON ALL TABLES IN SCHEMA nomadfi FROM PUBLIC;
