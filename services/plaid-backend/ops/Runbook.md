# Hosted pilot operations

Status: implementation reference, not a deployment record. H0 remains open.
No cloud project, paid plan, Apple key, KMS key, or Canadian hosting region has
been provisioned by this work. Current tests use synthetic upstream responses.

## Configuration

The API, worker, and sweep use the same image and private service configuration.
Use Node 24 LTS. `npm start`, `npm run worker`, and `npm run sweep` run locally;
the container command is `node src/runtime.js api`, `worker`, or `sweep`.

| Variable | Meaning |
| --- | --- |
| `DATABASE_URL` | Private runtime-role PostgreSQL connection, injected as a secret |
| `DATABASE_CA` | PEM CA when a private managed TCP connection needs it |
| `PLAID_ENVIRONMENT` | Explicit `sandbox` or `production`; separate database/key per environment |
| `PLAID_CLIENT_ID`, `PLAID_SECRET` | Server-only credentials from secret storage |
| `PLAID_REDIRECT_URI` | Registered HTTPS universal link, matching the iOS associated domain |
| `PLAID_WEBHOOK_URL` | Public HTTPS API `/webhooks/plaid` endpoint |
| `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID` | Native app identity and signing key metadata |
| `APPLE_PRIVATE_KEY` | Apple `.p8` content injected from secret storage |
| `APPLE_ALLOWED_SUBJECTS` | Comma-separated verified owner subjects; no automatic first-user enrollment |
| `TOKEN_ENCRYPTION` | `local` only for local sandbox; `kms` for hosted execution |
| `LOCAL_TOKEN_KEY` | Random 32-byte base64 key for private local sandbox only |
| `KMS_KEY_NAME` | Full symmetric CryptoKey resource; service identity receives scoped encrypt/decrypt access |
| `RATE_HASH_KEY` | Random 32-byte base64 key shared across service instances |
| `HOSTED_DATA_ACCEPTANCE` | `reviewed` only after H0 privacy, cost, region and retention acceptance is recorded |
| `PORT` | Loopback 8788 locally; container port 8080 by default |

Never paste these values into issues, source files, screenshots, logs, or build
arguments. `.dockerignore` allows only runtime source, migrations and lockfiles.
Changing encryption keys without preserving decryption capability strands
existing tokens; use KMS automatic versions under the same CryptoKey. Moving
to a different CryptoKey requires an explicit re-encryption migration.

## Deployment sequence

1. Record H0 decisions and a Canadian region. Create separate sandbox and
   production projects/databases or equivalent strongly isolated resources.
   Confirm actual service availability and backups in the selected region.
2. Provision private PostgreSQL with encryption, point-in-time recovery and
   a documented backup expiry. Disable any direct mobile data API. Run
   migrations with a dedicated owner, then `ops/roles.sql` as that owner.
   Grant the application login membership in `nomadfi_runtime`, never the
   migration owner. FiBot's separate login receives only `nomadfi_fibot`;
   it receives neither secret-reader nor KMS decrypt permissions.
3. Build the Docker image, scan it, and record the immutable digest. Deploy
   the API as a Cloud Run service with one pilot instance maximum, scoped
   Secret Manager access, KMS access, and Cloud SQL Client permissions.
   Use the managed Cloud SQL socket, or verified TLS with a trusted CA;
   certificate verification must not be disabled. Only the API is public.
4. Deploy Cloud Run jobs from the same digest for `worker` and `sweep`.
   Schedule the worker every minute and sweep hourly using a separate
   Scheduler identity granted job invocation only. Duplicate executions are
   fenced by database leases. Set one task per invocation and bound execution
   timeout/retries. The worker handles at most 50 claims per run. Measure the
   longest initial-history sync before choosing the job timeout.
5. Configure Apple sign-in and server notifications, register the Plaid HTTPS
   callback/webhook, and verify universal links on a physical iPhone. Do not
   transfer the current CIBC token or stop its broker during staging.
6. Exercise a real sandbox Link, delivery, restart, reconnect and account
   deletion. Check upstream removal, database erasure, backup expiry policy,
   traffic limits and failure alerts. Only then enable the hosted iOS pilot.

References: [Cloud Run/Cloud SQL](https://docs.cloud.google.com/sql/docs/postgres/connect-run),
[scheduled Cloud Run jobs](https://docs.cloud.google.com/run/docs/execute/jobs-on-schedule),
[Node release support](https://nodejs.org/en/about/previous-releases).

## Failure and recovery

- **Failed bank sync:** inspect state/counts, not payloads. Workers retain the
  previous committed cursor. Correct upstream/configuration issues before
  clearing a dead-letter job. Update mode repairs consent without replacing
  the connection or cursor. Repeated jobs must never invoke paid refresh APIs.
- **Ambiguous exchange:** an `exchanged` row contains an encrypted receipt and
  can resume attachment with the original attempt/public token. An
  `exchanging` timeout or `recovery_required` state needs Plaid Dashboard/support
  reconciliation to identify and revoke an orphan Item before cancelling that
  attempt. Do not purge the row merely because it is old. No endpoint reveals
  its encrypted receipt or underlying access token.
- **Deletion pending:** user sessions and sync stop immediately. Retry failed
  revocations after fixing upstream access. Keep the user in `deleting` until
  every upstream grant is revoked and ambiguous exchanges are resolved. Alert
  on any dead-letter revocation or deletion that exceeds the stated SLA.
- **Lost refresh response:** perform native Apple sign-in again. Replaying a
  rotated refresh token invalidates its session family by design.
- **Expired bootstrap:** discard unfinished staged pages, request a new
  snapshot, and leave committed device data/checkpoint intact until complete.

Alert on oldest runnable job age, dead-letter count, pending deletions, repeated
HTTP 5xx, database connection failures, and stale bank observations. Logs may
include error classifications and request IDs; exclude account names, amounts,
provider payloads, tokens and authorization headers. Export aggregate metrics
from the private database rather than adding a public diagnostics route.

## Restore and rollback

Practice restore into an isolated database with provider egress disabled.
Verify foreign keys, generation/cursor correspondence, owner separation,
encrypted-token readability with the retained KMS versions, and device replay.
Keep a separately protected deletion ledger for backup restoration so erased
users are removed again before enabling egress. This ledger/backup integration
must be supplied by the selected host; application cascade deletion alone does
not erase historical backups.

Roll back the application image by digest. Migrations are forward-only and
checksummed; never edit applied SQL or rewind provider cursors. If a schema
change prevents image rollback, deploy a compatible forward fix. Pause worker
scheduling during incident diagnosis while keeping the authenticated read API
available when safe. Re-enable workers after a synthetic restore/replay check.
