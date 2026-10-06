# Plaid Live-Data Preflight — Phase 5E

Updated October 5, 2026. This checklist validates one Canadian institution
on a physical iPhone. The April 24 sandbox run already proved the plumbing;
see [the result](./PlaidSandboxProof.md#01-first-real-device-sandbox-run-april-24-2026).
The filename is retained for existing links.

**October 5 live result:** production credentials and the signed-in team
were verified. On the physical iPhone, a Canadian institution's Link/MFA
and public-token exchange succeeded. The first sync imported accounts and
transactions; the repeat sync created no duplicates according to its
summary counters. Institution labels were verified in Financial Setup.
The institution and exact counts are retained only in private evidence.
This establishes live connectivity and repeat-sync behavior for
this session, not long-term reliability or complete transaction coverage.

The on-device validation session was marked **inconclusive** for the full
acceptance checklist: comparison with bank records and review of the
complete reconciliation artifact remain outstanding. Imported accounts
have no jurisdiction assigned, so they do not yet appear in a country
dashboard; prior sandbox accounts remain present. Private observations
are in the gitignored `PlaidValidationEvidence/` directory, and the
finalized export remains available in the phone's harness.

The interrupted-exchange recovery fix is installed: an unexpired public
token survives app restart in device-only Keychain storage, retries use
the original broker URL, and the running broker replays completed
exchanges. Validation passed 26 broker tests and 46 focused iOS tests.
Broker restarts still lose its in-memory access tokens and exchange cache.

Apple's FinanceKit request was closed on April 28 because of
developer-region availability; it is no longer a pending dependency.
Production rollout, durable token storage, and sustainable pricing remain
separate decisions.

## 1. Establish account access

Check the signed-in [Plaid Dashboard](https://dashboard.plaid.com/).
Record status locally without copying keys or private account details:

- [ ] Correct NomadFi team selected.
- [ ] Actual plan recorded: Trial, legacy Limited Production, paid
  Production, or Sandbox only / application pending.
- [ ] Production access approved; submission alone is not approval.
- [ ] Transactions and Canada enabled for this team.
- [ ] Production secret available locally. Sandbox keys do not establish
  production access.
- [ ] Remaining Item allowance and applicable charges checked.
- [ ] One institution chosen by the developer, using their own account.

Plaid offers Trial plans for eligible new US/Canadian teams created on or
after April 15, 2026. Legacy Limited Production and Trial are different
plans on the same `production` API environment. Check the actual Dashboard
rather than assuming which plan this team has.
[Plan documentation](https://plaid.com/docs/account/billing/).

Trial includes Transactions and permits 10 production Items. Removing an
Item does not restore its slot. Trial application requires accepting an
agreement; the account owner must review applications, attestations, and
any paid upgrade. [Trial details](https://support.plaid.com/hc/en-us/articles/39994173227159-What-is-the-Plaid-Trial-plan).

Suggested use-case text, if the Dashboard requests it:

> NomadFi is a cross-border financial decision assistant for international
> students and temporary residents. This developer evaluation reads
> Canadian account information, cached balances, and transactions to
> validate account mapping and reconciliation on an iPhone. It does not
> initiate payments or request account/routing numbers through Auth.

## 2. Use the minimum product scope

Use `PLAID_COUNTRY_CODES=CA` and `PLAID_PRODUCTS=transactions`.
The broker reads accounts and cached balances through `/accounts/get`;
it does not call `/auth/get` or `/accounts/balance/get`. A cached balance
is not proof of a real-time Balance refresh.

Do not list `balance` in Link's products array. Auth is unnecessary for
this run, and required products restrict which institutions and account
types Link offers. [Link API](https://plaid.com/docs/api/link/).

Canadian institutions currently do not use Plaid OAuth. Leave
`PLAID_REDIRECT_URI` empty for this Canada-only run. Follow the
authentication and MFA flow Link presents. A missing
`universal_link_observed` event is **not a failure** for this run.
[OAuth guide](https://plaid.com/docs/link/oauth/).

## 3. Prepare the local broker

Install locked dependencies with `npm ci` in `tools/plaid-sandbox-broker`.
Preserve an existing `.env`; copy `.env.example` only when creating one
for the first time.

When production access is confirmed, configure the gitignored `.env`:

```dotenv
PLAID_CLIENT_ID=<existing team client id>
PLAID_SECRET=<production secret>
PLAID_ENV=production
PLAID_LIVE_DATA_EVALUATION=1
PLAID_COUNTRY_CODES=CA
PLAID_PRODUCTS=transactions
PLAID_REDIRECT_URI=
PORT=8787
PLAID_BROKER_BIND_HOST=<Mac LAN IP>
PLAID_BROKER_SHARED_SECRET=<shared secret of at least 16 characters>
```

Run `npm run preflight` to validate local configuration without printing
credentials or contacting Plaid. This cannot establish account approval.
Start with `npm start` only for the device session.

Production requires the explicit opt-in flag. The broker rejects invalid
product/country lists, `balance` in Link products, and LAN mode without the
shared secret. `/sandbox/item/create` returns HTTP 410 in production:
use **Link a sandbox bank with Plaid Link**, not **Authorize**. The label
is historical; `/health` identifies the actual environment.

Access tokens are held in memory. Restarting the broker invalidates the
app's opaque handle. Keep it running through both sync checks; do not
repeatedly create Items to work around lost state. Persistent token storage
and reconnection handling remain rollout prerequisites. Stopping the
broker or clearing the iOS handle does not revoke the Plaid Item or stop
paid subscription billing; plan Item removal in the Dashboard before
finishing an evaluation.

## 4. Run on the iPhone

- [ ] Complete §1; do not substitute sandbox success for access approval.
- [ ] Mac and iPhone on the same trusted network; broker in production
  evaluation mode with shared-secret protection.
- [ ] Run NomadFi DEBUG from Xcode. Open Settings → Financial Setup →
  Financial Connections → Plaid sandbox developer harness.
- [ ] Save the broker URL and matching shared secret.
- [ ] **Start validation session**, then enable **Include institution
  name in export** (the toggle appears during a running session).
- [ ] Run the health check so the artifact records `env=production`, `reachable=true`, and
  `requires_secret=true`. `redirect_uri_configured=false` is expected.
- [ ] Return to Financial Connections and tap **Link a sandbox bank
  with Plaid Link**. Select the chosen Canadian institution.
- [ ] The account owner completes credentials, MFA, and consent in Link.
  Never place bank credentials in chat, the broker, or evidence files.
- [ ] Confirm Link success and public-token exchange.
  If exchange is interrupted, restore the original broker/network and
  use **Retry finishing link** within 30 minutes. The pending exchange
  survives an iOS app restart in device-only Keychain storage. Keep the
  broker process alive so completed exchanges can be replayed safely.
- [ ] Tap **Sync Now** and inspect the account/reconciliation result.
  Transactions can take time to become available. An empty first diff
  does not establish that the institution has no transaction history.
- [ ] Once data is available, run **Sync Now** again in the same broker
  session. Check that accounts/transactions are not duplicated.
- [ ] Record `pass`, `fail`, or `inconclusive` based on §5, with the
  institution and authentication method in the note.
- [ ] End the session and export Markdown to the gitignored
  `docs/research/PlaidValidationEvidence/` directory.
- [ ] Complete planned Item cleanup in the Dashboard, stop the broker,
  and restore sandbox credentials, `PLAID_ENV=sandbox`, an empty live-data
  flag, and loopback binding.

## 5. Interpret the evidence

**Pass for this institution:** production mode, successful Link and
exchange, intended institution name, at least one mapped account, no
ambiguous reconciliation, and successful sync and repeat-sync checks
without duplicates. Verify available recent transactions against the
selected account on-device. If the account has no transactions, state
that limitation; transaction coverage remains unproven. OAuth return is
required only for an institution that actually uses OAuth.

**Fail for this run:** reproducible broker, exchange, mapping, or
reconciliation errors. Fix implementation/configuration failures before
concluding that the provider lacks coverage.

**Inconclusive:** account approval or product/country permission missing,
Item cap reached, institution unavailable, authentication unfinished,
or expected transaction history still pending. Record the exact stage and
a redacted error code. An unavailable bank is evidence about that
bank/session, not every Canadian institution. A second bank requires the
developer's choice and a check of the remaining Item allowance.

Only a completed live run resolves criterion 5. Pricing approval,
long-term reliability, transaction removals, token persistence, and
multi-user onboarding are not proven by this checklist.

## 6. Separate OAuth readiness issue

The Canadian run does not depend on the existing GitHub Pages redirect.
Before testing an OAuth institution, repair and verify that setup:

- `https://arieltyson.github.io/.well-known/apple-app-site-association`
  returned **404** in the October 5 check.
- The file under `/nomadfi-privacy/.well-known/` returned **200**, but
  that project subdirectory is not the domain-root AASA location.
- Its rules were `/plaid-oauth` and `/plaid-oauth/*`; the configured
  redirect path is `/nomadfi-privacy/plaid-oauth`.

Serve the AASA at the domain's `/.well-known/` path, include app ID
`2MPMKAF986.com.arieljtyson.NomadFi`, and match both
`/nomadfi-privacy/plaid-oauth` and `/nomadfi-privacy/plaid-oauth/*`.
Register the exact HTTPS redirect in Plaid's allowed redirect settings,
verify the response and MIME type without redirects, and test on-device.
A project-site deployment alone does not fix the domain-root location.
[Apple associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).

The broker conservatively requires a redirect for production runs that
include countries outside Canada. This is a local guardrail, not a claim
that every institution in those countries uses OAuth.
