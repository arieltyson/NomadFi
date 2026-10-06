# NomadFi PostgreSQL storage

Local storage implementation for the [hosted sync plan](../../docs/PlaidHostedSyncPlan.md).
This implements part of H1 and the persistence contracts used by H2/H3. It is
not a running Plaid API, authenticated service, or deployed financial backend.
No live credentials or bank records are needed by these commands.

## Run locally

Use a current supported Node.js LTS release (minimum 22.18):

```sh
cd services/plaid-backend
npm ci
npm test
```

Tests start a real temporary PostgreSQL server on loopback with a randomly
generated password, apply the migrations, exercise concurrent transactions,
then stop the server and delete its temporary data. They do not use an
external `DATABASE_URL` or modify any existing database. The pinned
`embedded-postgres` prerelease wrapper is a development-only dependency that
ships PostgreSQL binaries; it is not a production hosting solution.

For a persistent local database, run in one terminal:

```sh
npm run db:local
```

Then in another terminal in this directory:

```sh
npm run db:migrate
```

The server binds `127.0.0.1:55432` and stops on Ctrl-C. Its data and credentials
are private, ignored local files; `.env.local` is generated automatically.
These are development commands only. The migration runner also works with a
separately configured PostgreSQL database, including Docker-managed instances.
It checks migration digests and refuses modified migration history. Supply
managed-database TLS and network configuration through the deployment layer.

## Storage contract

- `users`: Apple subject mapping and a transactionally serialized delivery
  revision. Only a future verified authentication service may call
  `createUser`; accepting a client-supplied Apple subject is not authentication.
- `connections`: owner/environment/provider identity, health, and committed
  upstream cursor. A provider Item cannot be attached to multiple users.
- `credentials`: separate opaque encrypted-token bytes and key reference.
  The caller must provide authenticated encryption; the store does not encrypt
  tokens itself. Production key management and encryption are not yet wired.
- `sync_jobs`: one durable coalesced request per connection, request/completion
  revisions, retry backoff, lease epoch/expiry, and dead-letter state.
- `sync_generations` and `sync_events`: ordered, immutable published deltas.
  Staged pages are invisible until publication. Account and transaction IDs
  are scoped to a connection; repeated modifications are ordered changes,
  not duplicate identities in a materialized account ledger.
- `device_checkpoints`: independent, monotonic acknowledgments. Call
  `acknowledge` only after the device commits the delivered data locally.

The API must derive `userID` from a verified session. Do not expose this store,
database credentials, or financial tables directly to mobile clients. Tables
are in a private schema with public grants revoked; separate least-privilege
runtime/migration/FiBot roles must be provisioned with the eventual service.
There is no public database API or permissive row-level policy in this slice.

## Worker protocol

1. `requestSync` durably records work before acknowledging a verified webhook.
2. `claim` uses a short `SKIP LOCKED` transaction. Network calls happen after
   it commits. The worker must renew its lease before expiry during long runs.
3. `beginGeneration` captures the currently committed upstream cursor.
4. `stagePage` accepts sequential, cursor-linked bounded pages. The caller maps
   provider payloads to minimal domain events; it must not forward secrets or
   unrestricted raw payloads. A page marked `hasMore: false` seals the generation.
5. `publish` checks ownership, lease, completion, and the original cursor. It
   atomically publishes the generation, advances the cursor and user delivery
   revision, and completes only the request revision claimed by that worker.
   A webhook received during fetching therefore remains queued for another pass.
6. `fail` applies bounded retry delay. Eight failures or expired-worker crashes
   dead-letter the job for operator review; new webhooks do not silently clear
   that state. Reconnect and operator retry workflows belong to the next slice.

Readers use `changes` with a fixed `through` revision and `(revision, offset)`
checkpoint. The terminal offset `2147483647` means the entire revision has
been consumed, including empty generations. Revisions are serialized by the
owner row held through commit; a plain sequence would not establish commit
order. Keep revisions as strings/BigInt, never JavaScript floating-point IDs.

## Verified and remaining work

Real PostgreSQL tests cover tenant constraints, additive connections, hidden
partial generations, atomic rollback, concurrent/delayed publication, stale
worker fencing, heartbeat expiry, mid-sync requests, retry isolation, bounded
delivery, independent acknowledgments, and database restart persistence.

Before deployment, implement the Apple sign-in/session lifecycle, encryption
adapter, Link exchange recovery, provider mapping and sync pagination retry,
signature-verified webhook receiver, worker scheduling, current-snapshot
bootstrap/materialization, expired-checkpoint retention, staged-data cleanup,
revocation/deletion, restricted runtime roles, and backup/restore procedures.
These remain explicit plan milestones; passing storage tests does not mark
H1–H3 complete or establish live bank connectivity.
