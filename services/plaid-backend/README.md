# NomadFi hosted backend

Local storage implementation for the [hosted sync plan](../../docs/PlaidHostedSyncPlan.md).
This implements part of H1 and the persistence contracts used by H2/H3. It is
not yet a deployed financial backend. Provider calls in tests use synthetic
fixtures; no live bank integration is claimed by passing those tests.
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
  revision. Only the verified authentication service may call
  `createUser`; accepting a client-supplied Apple subject is not authentication.
- `connections`: owner/environment/provider identity, health, and committed
  upstream cursor. A provider Item cannot be attached to multiple users.
- `credentials`: separate opaque encrypted-token bytes and key reference.
  The caller must provide authenticated encryption; the store does not encrypt
  tokens itself. AES-GCM is available for local development; the KMS adapter
  uses authenticated context binding owner, resource, environment, and purpose.
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

## Identity and token security

`AppleIdentity` verifies Apple's signature, issuer, client audience, expiry,
and recent issuance. `AuthService` binds sign-in to a five-minute, one-use
server nonce and independently checks the authorization-code exchange identity.
Only explicitly allowed Apple subjects can enter the owner pilot. The client
must send the issued nonce in its native Apple authorization request.

App access credentials expire after 15 minutes. Refresh rotates both app
credentials, expires after 30 idle days, and requires sign-in after 90 days.
Reusing a spent refresh credential revokes that session family. Clients must
serialize refresh and request fresh Apple sign-in after a lost refresh response;
blind retries deliberately fail closed. Apple grants are revalidated when
refreshing after 24 hours. Sign-out revokes the local app session; account
deletion must additionally revoke upstream Apple and Plaid grants.

Only hashes of app credentials are persisted. Apple/Plaid credentials use
separate authenticated contexts. `LocalTokenCipher` takes a random 32-byte key
from private local configuration; `KMSTokenCipher` uses a configured Google
Cloud symmetric key and application default credentials. No keys are committed.
The KMS contract is tested with a fake client, not a provisioned cloud key.
Cloud IAM, TLS, edge abuse controls, revocation notifications, and a deployable
HTTP boundary remain deployment requirements.

## Connections and HTTP contract

The HTTP factory derives ownership from opaque app sessions, limits request
sizes and traffic in PostgreSQL, preserves webhook bytes, and returns only
allowlisted error codes. Diagnostics never include bodies, headers, credentials,
provider messages, or financial records. Ingress limits use the socket address;
the service does not trust arbitrary forwarded IP headers. A managed edge must
enforce its own limits before internet deployment.

Unauthenticated routes: `POST /auth/challenge`, `/auth/apple`, `/auth/refresh`,
and `/webhooks/plaid`. Authenticated routes: `GET /connections`, `POST /link`,
`/link/exchange`, `/connections/:id/updated`, `/connections/:id/sync`,
`/snapshots`, `/acknowledgments`, `/auth/logout`; `GET /snapshots/:id` and
`/changes`; `DELETE /connections/:id` and `/account`. Mutations require a JSON
object, including `{}` when no fields are needed. There is no worker trigger
or administrative endpoint on the public API.

Link requests Transactions for CA/US with a configured HTTPS OAuth return.
Update mode reuses the existing Item, cursor, and token. A new connection is
additive. Exchange retries are bound to the authenticated owner, attempt, and
original public-token digest. An encrypted exchange receipt is committed before
attachment, so an attachment failure can resume without exchanging twice.
There is an unavoidable ambiguity if the process loses Plaid's successful
response before that receipt commits: `LINK_RECOVERY_REQUIRED` requires a fresh
Link/support reconciliation, never invented success. Such attempts block final
account purging until an operator verifies/revokes any orphan Item. They must
not be blindly removed by retention jobs.

Snapshots freeze ledger rows and a delivery revision for one hour. Apply every
snapshot page locally, then consume `/changes` starting at its checkpoint.
An expired snapshot returns 410 and must restart. Incremental generations are
currently retained indefinitely; no expired-cursor pruning is enabled.
Acknowledge only after saving local records and the checkpoint together.

Disconnect prevents further sync immediately and queues upstream revocation;
credentials remain encrypted until that succeeds. Existing financial history
is retained on disconnect. Account deletion disables sessions immediately,
revokes Plaid and Apple grants through fenced retry jobs, then cascades hosted
records. Failed/ambiguous revocations retain a visible operator backlog instead
of falsely reporting erasure. Backup expiry must match the deployed retention
policy before hosted data is accepted.

References: [Apple identity verification](https://developer.apple.com/documentation/signinwithapple/verifying-a-user),
[Google Cloud KMS authenticated encryption](https://docs.cloud.google.com/kms/docs/encrypt-decrypt).

## Verified and remaining work

Real PostgreSQL tests cover tenant constraints, additive connections, hidden
partial generations, atomic rollback, concurrent/delayed publication, stale
worker fencing, heartbeat expiry, mid-sync requests, retry isolation, bounded
delivery, independent acknowledgments, and database restart persistence.

Identity tests additionally cover nonce replay, tenant allowlisting, credential
rotation/reuse, grant validation, logout, deletion state, JWT validation, and
encrypted context substitution.

`SyncWorker` now calls the provider through a bounded, redacted HTTP client,
restarts pagination mutations from the committed cursor, and publishes a
materialized ledger in the same transaction as delivery events and cursor
advancement. Amounts are serialized as decimal strings; cached balance fetch
time is distinct from the provider's balance observation time. Missing
currencies and observation timestamps remain unknown. Pending replacements,
modifications, removals, and account tombstones retain connection identity.

`WebhookService` verifies ES256 signatures, bounded token age, and the hash of
the original request bytes before parsing or enqueuing. Its receipt and job
update commit together. Duplicate deliveries do not add work. A scheduled
catch-up helper coalesces requests for stale banks; it does not purchase a
Transactions Refresh call. Failures use capped backoff and reconnect state is
isolated per bank. Tests cover mutation recovery, failure after partial paging,
materialization, signature/body tampering, receipt rollback, and stale sweeps.

Provider contracts follow [Plaid sync pagination](https://plaid.com/docs/api/products/transactions/)
and [webhook verification](https://plaid.com/docs/api/webhooks/webhook-verification/).

Before deployment, complete Apple server notification handling, deployed
webhook/worker scheduling, expired-checkpoint retention, staged-data cleanup,
restricted runtime roles, recovery operations, and backup/restore procedures.
These remain explicit plan milestones; passing storage tests does not mark
H1–H3 complete or establish live bank connectivity.
