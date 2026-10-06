CREATE TABLE nomadfi.apple_events (
    id_digest bytea PRIMARY KEY,
    received_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON nomadfi.apple_events FROM PUBLIC;
