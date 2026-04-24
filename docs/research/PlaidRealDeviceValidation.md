# Plaid Real-Device Validation — Phase 5D Operational Runbook

Hands-on checklist for resolving criterion 5 of the bakeoff memo
([`OpenFinanceProviderBakeoff.md`](./OpenFinanceProviderBakeoff.md))
and the Phase 5D sandbox proof
([`PlaidSandboxProof.md`](./PlaidSandboxProof.md)) — running one real
Plaid Link flow against at least one of NomadFi's target Canadian
FIs on a physical iPhone.

This is a **developer-only** validation path. Nothing in here ships
to production; every piece of the harness is gated on DEBUG builds or
an explicit broker-side flag.

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
- The public site (`nomadfi-privacy`) must be deployed at
  `https://arieltyson.github.io/nomadfi-privacy/` with
  `.well-known/apple-app-site-association` and `/plaid-oauth/`
  reachable.

### 1.1 Verify the public site

```sh
curl -sS -I https://arieltyson.github.io/nomadfi-privacy/.well-known/apple-app-site-association
curl -sS -I https://arieltyson.github.io/nomadfi-privacy/plaid-oauth/
```

Both should return `HTTP/2 200`. The AASA's `Content-Type` must be
`application/json`. If either fails, the universal link cannot
fire; resolve that before continuing.

---

## 2. Start the broker in LAN mode

```sh
cd tools/plaid-sandbox-broker
cp .env.example .env
```

Edit `.env`:

```
PLAID_CLIENT_ID=…                           # sandbox key
PLAID_SECRET=…                              # sandbox key
PLAID_ENV=sandbox
PLAID_COUNTRY_CODES=US,CA
PLAID_PRODUCTS=transactions,auth,balance
PLAID_SANDBOX_INSTITUTION_ID=ins_109508
PLAID_REDIRECT_URI=https://arieltyson.github.io/nomadfi-privacy/plaid-oauth
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
npm install
npm run start
```

The console should log:

```
[plaid-sandbox-broker] listening on http://192.168.1.42:8787 (env=sandbox, LAN + shared-secret required)
[plaid-sandbox-broker] REMINDER: only run LAN mode during active real-device validation, on a trusted network, behind a firewall.
```

Verify from the Mac:

```sh
curl -sS -H "X-NomadFi-Broker-Secret: <secret>" http://192.168.1.42:8787/health
```

Expected: `{"ok":true,"env":"sandbox","requires_secret":true,"redirect_uri_configured":true}`.

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
   `Broker reachable (env=sandbox, secret required, redirect configured).`

If any step fails, consult §6 before proceeding.

---

## 4. Run a Plaid Link session against a target Canadian FI

On the iPhone, back in the Financial Connections list:

1. The Plaid sandbox row now reports availability. Tap the "Plaid
   sandbox Link" section's **Link a sandbox bank with Plaid Link**
   button.
2. Plaid Link opens. Search for a target institution. **Vendor-
   reported:** per Plaid's
   [Plaid in Canada](https://plaid.com/en-ca/) page, the following
   Canadian FIs appear on Plaid's marketed Canadian coverage. This
   list is Plaid-reported; the only authoritative source per FI is
   what Plaid Link actually offers during this session:
     - RBC Royal Bank
     - TD Canada Trust
     - Scotiabank
     - BMO Bank of Montreal
     - CIBC
     - Tangerine
     - Simplii Financial
3. Pick one. Complete the OAuth flow. Plaid redirects to
   `https://arieltyson.github.io/nomadfi-privacy/plaid-oauth?...`;
   iOS intercepts the universal link and relaunches NomadFi;
   LinkKit's `Handler.resumeAfterTermination(from:)` resumes the
   session and fires `onSuccess`.
4. The developer harness moves to **Plaid item linked (handle
   itm_...)**.

---

## 5. Verify snapshot reconciliation

Back on the Financial Connections page:

1. Tap **Sync Now**.
2. The Plaid sandbox row reports a successful sync. The bottom
   status line should read something like:
   `Synced. 1 new, 0 updated, 3 transactions imported.`
3. Open Settings → Financial Setup → Accounts. A new row should be
   present with the institution name reported by the broker
   (e.g. "RBC Royal Bank").
4. Open Dashboard. The net-worth + insights surfaces pick up the new
   account / transactions with `FinancialSnapshotSource.imported`
   provenance.

---

## 6. Evidence to capture

At minimum, save the following to `docs/research/PlaidValidationEvidence/`
(gitignored; never commit screenshots with real PII):

- Screenshot of the "Broker reachable" health line.
- Screenshot of the Plaid Link institution picker showing the target
  Canadian FI.
- Screenshot of the "Plaid item linked" status.
- Screenshot of the reconciliation summary line.
- Screenshot of the Dashboard or Accounts page with the new row.
- Free-text notes on any UX friction, unexpected errors, or missing
  coverage.

Evidence that remains private to the developer machine is fine — the
doc deliverable is the *decision* in §8 below, not the raw artifacts.

---

## 7. Pass / fail criteria

**Pass** when all of the following are true for one target Canadian
FI:

- Broker health check returned `reachable`.
- Plaid Link launched, authenticated, and delivered a `public_token`
  without a crash.
- `/item/public_token/exchange` succeeded; item handle persisted.
- `/accounts/get` returned at least one account; snapshot mapped
  cleanly through `PlaidSandboxSnapshotMapper`.
- `/transactions/sync` returned at least zero rows without throwing;
  cursor persisted after `FinancialDataReconciler.apply(...)`.
- Repeat Sync Now the next day produced an incremental diff (or an
  empty diff without crashing).
- No Plaid or iOS error log entries that indicate incorrect
  integration (OAuth redirect mismatch, bad entitlement, ATS
  blocked).

**Fail** if any of:

- Broker unreachable from the device (even with LAN mode + secret).
- Plaid Link opens but cannot find the target institution.
- OAuth redirect completes but NomadFi does not relaunch (AASA /
  associated-domains misconfigured).
- Plaid returns the `public_token`, but `/item/public_token/exchange`
  fails.
- Reconciliation writes produce duplicate accounts / transactions.

---

## 8. Decision branches after validation

### 8.1 Pass

Criterion 5 of the bakeoff memo resolves. The roadmap can move
forward as follows:

1. If Apple has also approved the FinanceKit capability AND the
   FinanceKit real-device bakeout passes, NomadFi's cross-border
   archetype now has two validated upstreams and Phase 5E (one
   concrete external adapter) becomes a decision rather than a
   gate — go or no-go based on cost modelling and product priority.
2. If FinanceKit has not cleared its own bar yet, NomadFi can still
   begin Phase 5E production-access conversations with Plaid —
   because the bakeoff memo's "no provider clears the bar yet"
   branch is closed by this pass.

Regardless of branch 1 or 2, **stop running LAN mode**. Switch the
broker back to `PLAID_BROKER_BIND_HOST=127.0.0.1`. The validation
harness is not a production backend.

### 8.2 Fail

Do not escalate to Phase 5E on this provider. Fall back to the
bakeoff memo's "no provider clears the bar yet" branch:

- Keep NomadFi on FinanceKit + manual + CSV.
- Leave the Plaid sandbox scaffolding inactive in production
  builds (the Settings row reads "Not enabled in this build" when
  the Keychain has no broker URL).
- Re-evaluate when (a) CFPB 1033 operationalization meaningfully
  moves the US coverage landscape, (b) Canada's Consumer-Driven
  Banking regime publishes developer-accessible endpoints, or
  (c) Apple's FinanceKit Canadian coverage materially expands.
- Optionally kick off an Akoya sandbox comparison at this point,
  but only if there's an explicit reason to believe Akoya's
  Canadian coverage or production onboarding differs meaningfully —
  that evidence must be primary-source before starting.

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
