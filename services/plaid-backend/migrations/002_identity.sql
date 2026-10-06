CREATE TABLE nomadfi.auth_challenges (
    id uuid PRIMARY KEY,
    nonce_digest bytea NOT NULL,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz
);
CREATE INDEX challenges_expiry ON nomadfi.auth_challenges (expires_at);

CREATE TABLE nomadfi.apple_grants (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES nomadfi.users(id) ON DELETE CASCADE,
    key_id text NOT NULL,
    encrypted_token bytea NOT NULL,
    verified_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    revoked_at timestamptz,
    UNIQUE (id, user_id)
);

CREATE TABLE nomadfi.sessions (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES nomadfi.users(id) ON DELETE CASCADE,
    apple_grant_id uuid NOT NULL,
    access_digest bytea NOT NULL UNIQUE,
    refresh_digest bytea NOT NULL UNIQUE,
    access_expires_at timestamptz NOT NULL,
    refresh_expires_at timestamptz NOT NULL,
    absolute_expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    revoked_at timestamptz,
    FOREIGN KEY (apple_grant_id, user_id) REFERENCES nomadfi.apple_grants(id, user_id)
);
CREATE INDEX sessions_owner ON nomadfi.sessions (user_id);

CREATE TABLE nomadfi.spent_refresh_tokens (
    digest bytea PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES nomadfi.sessions(id) ON DELETE CASCADE
);

REVOKE ALL ON ALL TABLES IN SCHEMA nomadfi FROM PUBLIC;
