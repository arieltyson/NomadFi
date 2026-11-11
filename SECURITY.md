# Security Policy

NomadFi handles people's bank balances and transactions. Security and
privacy are product requirements, not features, and every change is held
to them.

## Reporting a vulnerability

Please report suspected vulnerabilities **privately**, never in a public
issue, pull request or discussion. Contact the maintainer through the
address listed under **Contact** in the
[NomadFi Privacy Policy](https://arieltyson.github.io/nomadfi-privacy/privacy/),
with "NomadFi security" in the subject. Include what you found, how to
reproduce it and its impact. Please do not access, change or keep other
people's data while investigating, and give us reasonable time to fix the
issue before disclosing it.

You will get an acknowledgment within 3 business days and a status update
at least weekly until the issue is resolved.

## Supported versions

Only the latest build on `main` and the latest TestFlight or App Store
release receive security fixes.

## How NomadFi protects data

### On the iPhone

- **Files are unreadable while the iPhone is locked.** The app uses the
  `NSFileProtectionComplete` data-protection class, and files created before
  it (the SwiftData store, its journal, receipt images) are upgraded at
  launch (`FileProtectionHardener`).
- **Secrets live only in the Keychain**, as `WhenUnlockedThisDeviceOnly`
  items that never sync or migrate to another device.
- **Siri and Shortcuts cannot reach financial data from a locked iPhone.**
  Every background App Intent requires authentication, and a test pins
  this for each intent.
- **Widgets redact balances** on the Lock Screen and in StandBy.
- **Optional App Lock** (Face ID, Touch ID or passcode) and an app-switcher
  privacy blur.
- **Ask FiBot runs on device.** Questions, facts and answers never leave the
  iPhone, and every figure in an answer is checked against NomadFi's own
  records before it is shown.
- **Network:** HTTPS only under default App Transport Security, with no
  exceptions. The hosted client uses an ephemeral session with no cookies
  or cache and refuses redirects.
- **Logs** never mark balances, names, tokens or identifiers as public.

### Bank Connections (hosted, optional)

- **Identity:** Sign in with Apple only, with no name or email requested,
  bound to a one-use server nonce. During the pilot only allowlisted Apple
  accounts may sign in. App sessions are short-lived, refresh tokens rotate
  and replays revoke the session family, and only hashes are stored.
- **Bank tokens:** Plaid access tokens are encrypted with Google Cloud KMS
  using authenticated context that binds owner, connection, environment and
  purpose, so a token cannot be decrypted as anyone else's. The iPhone never
  receives a Plaid access token.
- **Webhooks:** Plaid webhooks are verified (ES256 signature, key ID, age and
  body hash) before anything is queued. Duplicates are ignored.
- **Database:** PostgreSQL in Canada, reachable only by NomadFi's server
  over certificate-verified TLS; plaintext connections are refused. All
  financial tables live in a private schema with public access revoked. The
  API, FiBot and migration roles are separate and least-privileged: the API
  cannot change the schema, and FiBot cannot read credentials. Supabase's
  Data API exposes no schemas and its sign-ups are disabled.
- **Cloud:** separate sandbox and production projects. Each service runs as
  its own identity with access only to the secrets and KMS key it needs;
  the scheduler may only start its two jobs; builds run without project
  Editor rights. Secrets live in Secret Manager in Montréal, and container
  images are built from a digest-pinned base.
- **API:** rate limits on every route, strict JSON with body limits, generic
  error responses, and hardened headers (HSTS, a deny-all Content Security
  Policy, no framing, no referrer).
- **Deletion:** disconnecting a bank revokes Plaid access before its token is
  deleted; deleting an account revokes Plaid and Apple grants and then
  erases every hosted record. Hosted data has no backups.

### Repository and supply chain

- No credentials, tokens, personal records, bank exports or production dumps
  are committed. Private evidence lives outside the repository and outside
  iCloud-synced folders (`~/.nomadfi-private`), linked at an ignored path.
- Pre-commit hooks run NomadFi's staged-security scanner and, when installed,
  Gitleaks with the rules in `.gitleaks.toml`. Install them with
  `scripts/install-hooks.sh`.
- GitHub Actions are pinned to full commit SHAs with minimal permissions.
  Dependabot alerts are enabled.

## Handling secrets (people and AI agents)

- Never paste a secret into chat, an issue, a commit, a screenshot, a shell
  argument or a log. Move secrets with `pbpaste | gcloud secrets create …`
  or from the macOS Keychain, and verify them by hash or with a read-only
  provider call, never by printing them.
- Never store a secret in a file under `~/Desktop` or `~/Documents`, which
  sync to iCloud Drive.
- Keep sandbox and production strictly separate: separate projects,
  databases, secrets and KMS keys.

## If something leaks

1. **Plaid secret:** rotate it in the Plaid Dashboard, add the new value as a
   new Secret Manager version, redeploy, then disable the old secret.
2. **Database password:** rotate the role password in Supabase, update the
   `database-url` secret and redeploy.
3. **Apple key:** create a new Sign in with Apple key, store it, redeploy and
   revoke the old key.
4. **Sessions:** revoke affected sessions; users sign in with Apple again.
5. Review Cloud Logging and Supabase logs for the exposure window and record
   what happened privately.

## Audit history

- **2026-11-10:** full review of the app, backend, cloud, database and
  repository. Fixed: background App Intents usable from a locked iPhone;
  default instead of Complete file protection; widgets showing balances when
  locked; an unused local-network ATS exception; plaintext Plaid secrets on
  disk in an iCloud-synced folder (deleted; rotation required); project
  Editor rights on the build identity; Supabase accepting non-TLS
  connections, public sign-ups and Data API schemas; missing API security
  headers; an unpinned base image; Dependabot alerts off.
