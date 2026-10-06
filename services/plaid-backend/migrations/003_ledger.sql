ALTER TABLE nomadfi.sync_events DROP CONSTRAINT sync_events_kind_check;
ALTER TABLE nomadfi.sync_events ADD CHECK
    (kind IN ('account', 'removed_account', 'transaction', 'removed_transaction'));

CREATE TABLE nomadfi.ledger_records (
    connection_id uuid NOT NULL,
    user_id uuid NOT NULL,
    kind text NOT NULL CHECK (kind IN ('account', 'transaction')),
    external_id text NOT NULL,
    payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    removed boolean NOT NULL DEFAULT false,
    revision bigint NOT NULL,
    PRIMARY KEY (connection_id, kind, external_id),
    FOREIGN KEY (connection_id, user_id)
        REFERENCES nomadfi.connections(id, user_id) ON DELETE CASCADE
);
CREATE INDEX ledger_records_owner ON nomadfi.ledger_records (user_id, connection_id);

INSERT INTO nomadfi.ledger_records (connection_id, user_id, kind, external_id, payload, removed, revision)
SELECT DISTINCT ON (e.connection_id, replace(e.kind, 'removed_', ''), e.external_id)
    e.connection_id, e.user_id, replace(e.kind, 'removed_', ''), e.external_id,
    e.payload, e.kind LIKE 'removed_%', g.delivery_revision
FROM nomadfi.sync_events e JOIN nomadfi.sync_generations g ON g.id = e.generation_id
WHERE g.published_at IS NOT NULL
ORDER BY e.connection_id, replace(e.kind, 'removed_', ''), e.external_id,
    g.delivery_revision DESC, e.ordinal DESC;

CREATE TABLE nomadfi.webhook_receipts (
    digest bytea PRIMARY KEY,
    received_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON ALL TABLES IN SCHEMA nomadfi FROM PUBLIC;
