# Plaid Real-Device Validation — Phase 5D Operational Runbook

Hands-on checklist for two related but **distinct** Phase 5D runs.
Each run produces a recorder artifact via the DEBUG-only validation
recorder; the artifact's evidence determines what was actually
proven.

| Run kind | What it proves | What it does **not** prove |
|---|---|---|
| **Sandbox plumbing run** (this runbook, §1–§5) | Real-device NomadFi + broker + LinkKit + exchange + `/accounts/get` + `/transactions/sync` + reconciliation all work end-to-end. Resolves Phase 5D execution / plumbing. Compatible with Plaid sandbox test institutions per [plaid.com/docs/sandbox/institutions/](https://plaid.com/docs/sandbox/institutions/) (vendor-reported). | Real CIBC / RBC / TD / Scotia / BMO / Tangerine / Simplii login. Real OAuth bank handoff. Per-FI Canadian coverage. **Does not resolve criterion 5.** |
| **Live-data Canadian-FI run** (§8) | One target Canadian FI under Plaid's production environment (Trial, legacy Limited Production, or paid access) with real user credentials. Resolves criterion 5. | Long-term unit economics, sandbox-vs-production fidelity in aggregate, broader-coverage claims for other FIs. |

This is a **developer-only** validation path. Nothing in here ships
to production; every piece of the harness is gated on DEBUG builds
or an explicit broker-side flag. The first sandbox plumbing run was
completed on April 24, 2026 with 10 accounts + 48 transactions
reconciled; see
[`PlaidSandboxProof.md`](./PlaidSandboxProof.md) §0.1 for the
artifact summary. The live-data run remains pending — see §8.

---

## 0. Who this is for

The NomadFi developer running Phase 5D validation on their own
machine + personal device. Not a production onboarding doc.

---

## 1. Prerequisites

- macOS dev machine with Xcode 26.4+ and Node 20+.
- Physical iPhone on iOS 26.4+, enrolled in the same Apple Developer
  Program account as `com.arieljtyson.NomadFi` and signed into the
  same iCloud account as the Mac.
- Mac and iPhone on the same trusted Wi-Fi network.
- Plaid sandbox credentials (dashboard → Team Settings → Keys →
  Sandbox). Never use production or development keys here.
- Public-site OAuth configuration is only needed when explicitly testing
  an OAuth institution. Canadian live-data validation does not require it.

### 1.1 OAuth-only prerequisite

Before an OAuth test, follow [preflight §6](./PlaidLimitedProductionReadiness.md#6-separate-oauth-readiness-issue).
The AASA must be served at the domain root's `/.well-known/` path and
match the full redirect path. The project-subdirectory file is insufficient.
The current root AASA returns 404; do not claim OAuth readiness from the
April sandbox pass. Plaid provides separate OAuth test institutions in
Sandbox; the April run did not exercise them.

---

## 2. Start the broker in LAN mode

```sh
cd tools/plaid-sandbox-broker
# Only when .env does not already exist:
cp .env.example .env
```

Edit `.env`:

```
PLAID_CLIENT_ID=…                           # sandbox key
PLAID_SECRET=…                              # sandbox key
PLAID_ENV=sandbox
PLAID_COUNTRY_CODES=CA
PLAID_PRODUCTS=transactions
PLAID_SANDBOX_INSTITUTION_ID=ins_109508
PLAID_REDIRECT_URI=
PORT=8787
PLAID_BROKER_BIND_HOST=<your-Mac-LAN-IP>    # e.g. 192.168.1.42
PLAID_BROKER_SHARED_SECRET=<32-char hex>    # openssl rand -hex 32
```

Find the Mac's LAN IP:

```sh
ipconfig getifaddr en0
```

Then:

```sh
npm ci
npm run preflight
npm run start
```

The console should log:

```
[plaid-broker] listening on http://192.168.1.42:8787 (env=sandbox, LAN + shared-secret required)
[plaid-broker] REMINDER: only run LAN mode during active real-device validation, on a trusted network, behind a firewall.
```

Verify from the Mac:

```sh
curl -sS -H "X-NomadFi-Broker-Secret: <secret>" http://192.168.1.42:8787/health
```

Expected: `{"ok":true,"env":"sandbox","requires_secret":true,"redirect_uri_configured":false}`.

---

## 3. Configure the iOS app on the device

1. Build and run NomadFi on the physical iPhone through Xcode (DEBUG
   configuration).
2. Wait for the Local Network permission prompt if it appears. The
   prompt text is NomadFi's `NSLocalNetworkUsageDescription`. Tap
   **Allow** (required — the device must reach the Mac).
3. Settings → Financial Setup → Financial Connections → scroll to
   the **Developer tools** section (only visible in DEBUG) → tap
   **Plaid sandbox developer harness**.
4. Paste the broker URL (`http://192.168.1.42:8787`) and the shared
   secret into the two fields, tap **Save broker config**. The
   status line should read "Broker URL saved."
5. Tap **Run health check**. The status icon should turn green and
   read:
   `Broker reachable (env=sandbox, secret required, redirect not configured).`

If any step fails, consult §6 before proceeding.

---

## 4. Run a sandbox Link session

On the iPhone, back in Financial Connections:

1. Tap **Link a sandbox bank with Plaid Link**.
2. Select a Sandbox test institution and use its synthetic credentials.
   Do not enter real bank credentials in Sandbox.
3. Complete the presented authentication flow. This ordinary sandbox
   run does not need an OAuth return; explicit OAuth tests are separate.
4. Confirm Link completion and the persisted opaque item handle.

This proves the plumbing only. Real Canadian-bank coverage requires §8.3.

---

## 5. Verify snapshot reconciliation

Back on the Financial Connections page:

1. Tap **Sync Now**.
2. The Plaid sandbox row reports a successful sync. The bottom
   status line should read something like:
   `Synced. 1 new, 0 updated, 3 transactions imported.`
3. Open Settings → Financial Setup → Accounts. A new row should be
   present with the institution name reported by the broker
   (the selected Sandbox institution).
4. Open Dashboard. The net-worth + insights surfaces pick up the new
   account / transactions with `FinancialSnapshotSource.imported`
   provenance.

---

## 6. Evidence to capture

At minimum, save the following to `docs/research/PlaidValidationEvidence/`
(gitignored; never commit screenshots with real PII):

- Screenshot of the "Broker reachable" health line.
- Screenshot of the Plaid Link institution picker showing the target
  institution.
- Screenshot of the "Plaid item linked" status.
- Screenshot of the reconciliation summary line.
- Screenshot of the Dashboard or Accounts page with the new row.
- Free-text notes on any UX friction, unexpected errors, or missing
  coverage.

Evidence that remains private to the developer machine is fine — the
doc deliverable is the *decision* in §8 below, not the raw artifacts.

---

## 7. Pass / fail criteria

**Pass** when all of the following are true for the selected sandbox
institution:

- Broker health check returned `reachable`.
- Plaid Link launched, authenticated, and delivered a `public_token`
  without a crash.
- `/item/public_token/exchange` succeeded; item handle persisted.
- `/accounts/get` returned at least one account; snapshot mapped
  cleanly through `PlaidSandboxSnapshotMapper`.
- `/transactions/sync` returned at least zero rows without throwing;
  cursor persisted after `FinancialDataReconciler.apply(...)`.
- Repeat Sync Now in the same broker session produced an incremental
  diff or an empty diff without duplicates. Restarting loses token state.
- No Plaid or iOS error log entries that indicate incorrect
  integration (OAuth redirect mismatch, bad entitlement, ATS
  blocked).

**Fail** if any of:

- Broker unreachable from the device (even with LAN mode + secret).
- Plaid Link opens but cannot find the target institution.
- During an explicit OAuth test, the redirect completes but NomadFi
  does not relaunch (AASA / associated-domains misconfigured).
- Plaid returns the `public_token`, but `/item/public_token/exchange`
  fails.
- Reconciliation writes produce duplicate accounts / transactions.

---

## 8. Decision branches after a sandbox plumbing run

These branches apply to the run kind described in §1–§7 above (the
sandbox plumbing run). A sandbox **pass** resolves Phase 5D
execution / plumbing only — it does **not** resolve criterion 5.
For criterion 5, see §8.3 (live-data run).

### 8.1 Sandbox pass

Plumbing is proven. Stop the broker (return
`PLAID_BROKER_BIND_HOST=127.0.0.1`) and proceed to §8.3 once you
want criterion-5 evidence.

### 8.2 Sandbox fail

Do not escalate to a live-data run on this provider — fix whatever
the sandbox artifact reveals first (recorder events, mapping bug,
reconciliation invariant break, or broker error). When the
sandbox plumbing run produces a clean artifact, only then move to
§8.3.

### 8.3 Live-data Canadian-FI run

Use the [live-data preflight](./PlaidLimitedProductionReadiness.md) as the
canonical checklist for access, configuration, execution, and outcomes.

1. Confirm the actual Dashboard plan, production approval, Canadian
   Transactions access, and remaining Item allowance.
2. The developer chooses one Canadian institution and completes its
   login/MFA/consent personally on the iPhone.
3. Configure `PLAID_ENV=production`, `PLAID_LIVE_DATA_EVALUATION=1`,
   production credentials, `PLAID_COUNTRY_CODES=CA`,
   `PLAID_PRODUCTS=transactions`, and an empty `PLAID_REDIRECT_URI`.
4. Start a recorder session before checking health. Export must establish
   `env=production` and record the intended institution name.
5. Run real Link, exchange, sync, and repeat sync in one broker session.
   Capture actual results rather than presuming a pass.
6. Apply preflight §5. `Universal-link return observed: no` is expected
   for the current Canadian non-OAuth flow; it is not a failure.
7. Export the redacted artifact, complete the planned Item cleanup, stop
   the broker, and restore sandbox credentials and loopback binding.

An unavailable institution or access limitation is inconclusive; a
reproducible implementation error is a failed run to fix. Neither alone
justifies abandoning all Canadian coverage. Cost and rollout readiness
remain separate from the result for this institution.

---

## 9. Security reminders

- The broker holds Plaid `client_id` / `secret`. Never push LAN
  mode to a public network, a coffee-shop Wi-Fi, or a VPS.
- Stop the broker (`Ctrl-C`) the moment validation is complete.
- Rotate the shared secret + regenerate Plaid sandbox keys if the
  Mac or iPhone is lost, serviced, or shared.
- The Keychain values on the device are device-only, not iCloud-
  synced (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). They
  wipe on "Delete All My Data".
- NomadFi's ATS policy uses the narrowest Apple-sanctioned
  exception (`NSAllowsLocalNetworking`), which only permits
  plain-HTTP loads to loopback, `.local`, and link-local / private
  IPv4/IPv6 ranges — not to arbitrary Internet hosts.

---

## 10. Primary sources

- Apple — Preventing Insecure Network Connections:
  https://developer.apple.com/documentation/security/preventing-insecure-network-connections
- Apple — `NSAllowsLocalNetworking`:
  https://developer.apple.com/documentation/bundleresources/information_property_list/nsapptransportsecurity/nsallowslocalnetworking
- Apple — Universal Links:
  https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html
- Plaid — Link iOS SDK:
  https://plaid.com/docs/link/ios/
- Plaid — Link OAuth:
  https://plaid.com/docs/link/oauth/
- Plaid — Sandbox:
  https://plaid.com/docs/sandbox/
- Plaid — Institutions:
  https://plaid.com/docs/institutions/
- Plaid in Canada:
  https://plaid.com/en-ca/
