CREATE SCHEMA nomadfi;
REVOKE ALL ON SCHEMA nomadfi FROM PUBLIC;

CREATE TABLE nomadfi.users (
    id uuid PRIMARY KEY,
    apple_subject text NOT NULL UNIQUE CHECK (length(apple_subject) BETWEEN 1 AND 512),
    state text NOT NULL DEFAULT 'active' CHECK (state IN ('active', 'deleting')),
    delivery_revision bigint NOT NULL DEFAULT 0 CHECK (delivery_revision >= 0),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE nomadfi.connections (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES nomadfi.users(id) ON DELETE CASCADE,
    environment text NOT NULL CHECK (environment IN ('sandbox', 'production')),
    provider_item_id text NOT NULL CHECK (length(provider_item_id) BETWEEN 1 AND 512),
    institution_name text CHECK (length(institution_name) <= 512),
    state text NOT NULL DEFAULT 'connected'
        CHECK (state IN ('connected', 'reconnect_required', 'revoking', 'disconnected')),
    upstream_cursor text,
    last_synced_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (environment, provider_item_id),
    UNIQUE (id, user_id)
);

CREATE TABLE nomadfi.credentials (
    connection_id uuid PRIMARY KEY,
    user_id uuid NOT NULL,
    key_id text NOT NULL CHECK (length(key_id) BETWEEN 1 AND 1024),
    encrypted_token bytea NOT NULL CHECK (octet_length(encrypted_token) >= 32),
    FOREIGN KEY (connection_id, user_id)
        REFERENCES nomadfi.connections(id, user_id) ON DELETE CASCADE
);

CREATE TABLE nomadfi.sync_jobs (
    connection_id uuid PRIMARY KEY,
    user_id uuid NOT NULL,
    requested_revision bigint NOT NULL DEFAULT 1 CHECK (requested_revision >= 1),
    completed_revision bigint NOT NULL DEFAULT 0,
    lease_epoch bigint NOT NULL DEFAULT 0 CHECK (lease_epoch >= 0),
    leased_request_revision bigint,
    lease_expires_at timestamptz,
    available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    dead_letter boolean NOT NULL DEFAULT false,
    failure_code text CHECK (failure_code IN ('upstream_unavailable', 'invalid_data', 'worker_failed')),
    CHECK (completed_revision >= 0 AND completed_revision <= requested_revision),
    FOREIGN KEY (connection_id, user_id)
        REFERENCES nomadfi.connections(id, user_id) ON DELETE CASCADE
);
CREATE INDEX sync_jobs_available ON nomadfi.sync_jobs (available_at, connection_id)
    WHERE NOT dead_letter;

CREATE TABLE nomadfi.sync_generations (
    id uuid PRIMARY KEY,
    connection_id uuid NOT NULL,
    user_id uuid NOT NULL,
    lease_epoch bigint NOT NULL,
    base_cursor text,
    next_cursor text,
    page_count integer NOT NULL DEFAULT 0 CHECK (page_count >= 0),
    event_count integer NOT NULL DEFAULT 0 CHECK (event_count >= 0),
    complete boolean NOT NULL DEFAULT false,
    delivery_revision bigint,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    published_at timestamptz,
    CHECK ((published_at IS NULL) = (delivery_revision IS NULL)),
    CHECK (delivery_revision IS NULL OR (delivery_revision > 0 AND complete)),
    UNIQUE (id, connection_id, user_id),
    UNIQUE (user_id, delivery_revision),
    FOREIGN KEY (connection_id, user_id)
        REFERENCES nomadfi.connections(id, user_id) ON DELETE CASCADE
);

CREATE TABLE nomadfi.sync_events (
    generation_id uuid NOT NULL,
    connection_id uuid NOT NULL,
    user_id uuid NOT NULL,
    ordinal integer NOT NULL CHECK (ordinal >= 0),
    kind text NOT NULL CHECK (kind IN ('account', 'transaction', 'removed_transaction')),
    external_id text NOT NULL CHECK (length(external_id) BETWEEN 1 AND 512),
    payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    PRIMARY KEY (generation_id, ordinal),
    FOREIGN KEY (generation_id, connection_id, user_id)
        REFERENCES nomadfi.sync_generations(id, connection_id, user_id) ON DELETE CASCADE
);

CREATE TABLE nomadfi.device_checkpoints (
    user_id uuid NOT NULL REFERENCES nomadfi.users(id) ON DELETE CASCADE,
    device_id uuid NOT NULL,
    revision bigint NOT NULL CHECK (revision >= 0),
    event_offset integer NOT NULL CHECK (event_offset >= -1),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (user_id, device_id)
);

REVOKE ALL ON ALL TABLES IN SCHEMA nomadfi FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA nomadfi REVOKE ALL ON TABLES FROM PUBLIC;
