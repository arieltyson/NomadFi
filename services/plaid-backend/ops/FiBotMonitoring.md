# Consented FiBot monitoring

The API accepts `POST /fibot/configuration` with an explicit boolean `consent`.
Enabling sends a bounded confirmed context, the exact engine policy, alert
categories, quiet hours, IANA time zone and optional snooze date. Updates require
the last `expectedRevision` from `GET /fibot`. The authenticated session supplies
ownership; client-provided owner IDs are never used. Disabling removes uploaded
context, jobs and derived alerts. Account deletion stops monitoring immediately.

Every committed bank generation invalidates previous advice and increments a
durable monitoring job in the same transaction. The daily sweep also queues
completed monitors. Workers claim expiring fenced leases and invoke the same
Swift executable used by the app, over bounded stdin/stdout with a timeout.
Eight failures enter a dead-letter state. A newer plan, bank revision, consent
withdrawal or deleted account prevents a stale evaluation publishing.

This first monitor consumes an explicitly uploaded manual plan. It **does not**
infer salary or replace confirmed accessible funds with cached bank balances.
A new bank revision or evaluation day requires renewed coverage confirmation.
Automatic bank-to-plan reconciliation remains a release gate, not an implied
feature. Results appear in the authenticated in-app alert feed. There is no
APNs delivery yet. `notification_at` records eligibility, not delivered push.
Eligibility respects quiet hours, snooze and a one/day, three/week cap; replay
does not duplicate an alert or undo dismissal. Alerts expire after 30 days.

Run the worker as a separate database login granted only `nomadfi_fibot`.
It cannot read identities, raw ledgers, Plaid/Apple credentials or sessions,
and cannot change context or consent. The `worker_lock` column exists only to
permit PostgreSQL row locking without granting writes to financial fields.
The consent-filtered connection view exposes status, not provider identifiers.

Worker configuration:

- `FIBOT_DATABASE_URL`: secret PostgreSQL URI, without query overrides.
- `FIBOT_DATABASE_SOCKET`: optional `/cloudsql/project:region:instance` socket.
- `FIBOT_DATABASE_CA_PEM`: trusted CA when using a TLS database connection.
- `FIBOT_ENGINE_PATH`: absolute path to the compiled `fibot-evaluate` executable.
- `RUNTIME_ENV=local`: permits loopback-only local development without TLS.
- Hosted execution requires the existing `HOSTED_DATA_ACCEPTANCE=reviewed` gate.

Do not give this process Plaid, Apple, KMS or API authentication secrets. Startup
rejects database roles with access to credentials/identities or full plan UPDATE.
Deploy `services/fibot-engine/Dockerfile` from the repository root. The `test`
target validates the Swift/Node/PostgreSQL integration as a non-root user. The
runtime intentionally retains official Swift runtime dependencies; image size
can be reduced after Linux compatibility is verified. GitHub Actions builds
and tests both targets without production credentials.

Hosted costs, region, backup retention, consent disclosures, daily scheduling,
private forecast reconciliation, financial-domain review and the prospective
pilot remain necessary before enabling this with live financial data.
