# Plaid Limited Production Readiness — Phase 5E Preflight

Operational preflight for the **one** real-target-Canadian-FI run
that resolves criterion 5 of
[`OpenFinanceProviderBakeoff.md`](./OpenFinanceProviderBakeoff.md).
The companion runbook step is
[`PlaidRealDeviceValidation.md`](./PlaidRealDeviceValidation.md) §8.3.
The April 24, 2026 sandbox plumbing run already passed
([`PlaidSandboxProof.md`](./PlaidSandboxProof.md) §0.1); this doc
covers everything the developer needs to assemble **before** the
live-data run can fire.

This is **not** the start of Phase 5E. Phase 5E remains blocked on:

1. a passing run against the runbook here, **and**
2. Apple's response to the FinanceKit capability request that was
   submitted in April 2026.

---

## 0. Vocabulary alignment with Plaid's own docs

Two distinctions matter, both vendor-reported by Plaid:

- **Sandbox vs Production.** Per
  [plaid.com/docs/sandbox/](https://plaid.com/docs/sandbox/) and
  [plaid.com/docs/api/](https://plaid.com/docs/api/), Plaid runs two
  environments NomadFi targets here: `sandbox` (free, pre-defined
  test institutions, test credentials) and `production` (real
  banks, real users, real Plaid pricing).
- **Production vs Limited Production.** Within `production`,
  Plaid's Dashboard onboarding path
  ([plaid.com/docs/api/](https://plaid.com/docs/api/), vendor-
  reported) places newly-approved apps in a Limited Production
  state with caps on connected items / users until commercial
  approval lifts those caps. Architecturally there is one
  production environment; "Limited Production" is a Plaid-side
  permission state on top of it.

The broker treats these as a single setting: `PLAID_ENV=production`
+ `PLAID_LIVE_DATA_EVALUATION=1`. Plaid's caps + dashboard approval
gate the actual access NomadFi gets — there is nothing for this
broker to enforce at the env-var level beyond the opt-in flag.

---

## 1. Manual Plaid Dashboard work (developer responsibility)

NomadFi cannot move into live-data evaluation until **all** of the
following are completed in the Plaid Dashboard for
`com.arieljtyson.NomadFi`'s Plaid account. Each item is a Plaid
process, vendor-reported:

- [ ] **Production access request submitted** through the Plaid
  Dashboard's production access workflow. Plaid currently requires
  a use-case description, expected volume, and an integration
  walkthrough.
- [ ] **Use-case description** consistent with NomadFi's product
  identity in [`docs/MISSION.md`](../MISSION.md): cross-border
  financial decision assistant for international students /
  temporary residents / immigrants, read-only Transactions / Auth /
  Balance products, no payment initiation.
- [ ] **Allowed redirect URIs** configured in the Plaid Dashboard's
  Link Customization settings to include exactly:
  `https://arieltyson.github.io/nomadfi-privacy/plaid-oauth`.
  (Per [plaid.com/docs/link/oauth/](https://plaid.com/docs/link/oauth/),
  vendor-reported, Plaid will reject Link sessions whose
  `redirect_uri` doesn't match an allowed entry.)
- [ ] **Products enabled** for live data: Transactions, Auth,
  Balance. Identity / Investments stay disabled until NomadFi has a
  product reason to use them.
- [ ] **Country codes selected** in the Dashboard: at minimum
  `US`, `CA`. (TT is not in Plaid's coverage; explicitly out of
  scope.)
- [ ] **Production keys issued** by the Dashboard. The previous
  sandbox keys remain valid; the developer keeps both pairs and
  swaps them in `.env` per run kind.

If any item is missing, Plaid will reject the run before it
reaches a real institution and the broker may either fail the
`/link/token/create` call (Plaid-side rejection) or surface an
unrelated error. The runbook accounts for both branches.

---

## 2. Apple side — what stays the same

The iOS-side OAuth plumbing shipped in Phase 5D gate-clearance is
not mode-specific:

- `applinks:arieltyson.github.io` associated-domains entitlement
  is already in `NomadFi/NomadFi.entitlements`.
- `.well-known/apple-app-site-association` is already deployed at
  `https://arieltyson.github.io/nomadfi-privacy/`.
- The redirect page at `/plaid-oauth/` is already deployed.
- `NSAppTransportSecurity.NSAllowsLocalNetworking=true` and
  `NSLocalNetworkUsageDescription` are already in
  `NomadFi-Info.plist` for talking to the local broker on Wi-Fi.

What does **not** carry over from sandbox to live-data runs:

- The DEBUG-only `requestAuthorization()` path on
  `PlaidSandboxFinancialDataProvider` calls the broker's
  `/sandbox/item/create` shortcut, which the broker now disables in
  live-data mode (HTTP 410). The harness's "Authorize" button is
  therefore **sandbox-only**. In live-data mode the developer uses
  the **"Link a sandbox bank with Plaid Link"** button on the main
  Financial Connections page (the label is historical — the
  underlying flow is the real Link flow regardless of mode).

---

## 3. Broker config for the live-data run

In `tools/plaid-sandbox-broker/.env`:

```
PLAID_CLIENT_ID=<your production client id>
PLAID_SECRET=<your production secret>

PLAID_ENV=production
PLAID_LIVE_DATA_EVALUATION=1

PLAID_COUNTRY_CODES=US,CA
PLAID_PRODUCTS=transactions,auth,balance

PLAID_REDIRECT_URI=https://arieltyson.github.io/nomadfi-privacy/plaid-oauth

PORT=8787
PLAID_BROKER_BIND_HOST=<your Mac LAN IP, e.g. 192.168.1.42>
PLAID_BROKER_SHARED_SECRET=<openssl rand -hex 32>
```

`PLAID_SANDBOX_INSTITUTION_ID` is ignored in production mode.

The broker will:

- start against `https://production.plaid.com`,
- print the **LIVE-DATA EVALUATION MODE** banner,
- disable `POST /sandbox/item/create` (HTTP 410),
- still enforce `X-NomadFi-Broker-Secret` on every request.

If any required env-var is missing or malformed, the broker exits
before binding to a port — the `code` in the startup error log
(`UNSUPPORTED_ENV` / `LIVE_DATA_NOT_OPTED_IN` / `MISSING_PLAID_CREDENTIALS`
/ `MISSING_REDIRECT_URI_FOR_PRODUCTION` / `LAN_MODE_MISSING_SECRET`)
maps directly to the §1 + §3 checklist.

---

## 4. The first live-data run — exact checklist

Each step has a checkbox so the developer can mark progress.

- [ ] §1 manual Plaid Dashboard work complete.
- [ ] iPhone + Mac on the same trusted Wi-Fi (or iPhone hotspot with
  the Mac on the hotspot).
- [ ] `tools/plaid-sandbox-broker/.env` updated per §3.
- [ ] Broker started; confirm console reads
  `LIVE-DATA EVALUATION MODE`.
- [ ] `curl http://<lan-ip>:8787/health` from the Mac with the
  shared-secret header returns `{"ok":true,"env":"production",…}`.
- [ ] NomadFi DEBUG running on the iPhone via Xcode.
- [ ] Settings → Financial Setup → Financial Connections → Plaid
  sandbox developer harness opens.
- [ ] Save broker URL + shared secret. Run health check. Status
  reads `Broker reachable (env=production, secret required, redirect configured).`
- [ ] **Toggle "Include institution name in export" ON.** This is
  the explicit consent that lets the artifact record which FI was
  tested.
- [ ] **Start validation session** in the harness.
- [ ] Navigate to Financial Connections list. Tap **Link a sandbox
  bank with Plaid Link** (label is historical; the flow is real
  Link).
- [ ] In Plaid Link, search for the chosen target Canadian FI.
  Vendor-reported coverage at
  [plaid.com/en-ca/](https://plaid.com/en-ca/): RBC / TD / Scotia /
  BMO / CIBC / Tangerine / Simplii. Pick **one**.
- [ ] Complete OAuth in the bank's UI with **real credentials**.
  iOS should reopen NomadFi via the universal link.
- [ ] Confirm the harness shows `Plaid item linked (handle itm_…)`.
- [ ] On Financial Connections, tap **Sync Now**. Confirm the
  reconciler summary line appears with non-zero counts.
- [ ] Return to the harness. Pick a result (`pass` / `fail` /
  `inconclusive`) + a one-line note naming the FI.
- [ ] **End session.**
- [ ] Tap **Export as Markdown**. Save the artifact.
- [ ] Stop the broker (Ctrl-C). Revert `.env` back to sandbox
  defaults.

---

## 5. Pass / fail / inconclusive criteria

Same shape as
[`PlaidValidationEvidenceTemplate.md`](./PlaidValidationEvidenceTemplate.md)
§5, with two **additional** live-data-only conditions:

- **Pass requires** `universal_link_observed` in the event log.
  Sandbox institutions don't trigger OAuth handoff; a real
  Canadian FI usually will. Absence of this event during a live-data
  run signals an associated-domains / AASA misconfiguration that
  must be resolved before claiming pass.
- **Pass requires** `institution_observed` with
  `display_name_included=true` and a `display_name` matching the
  FI the developer intended to test. Without this, the artifact
  cannot support a per-FI claim.

A live-data **fail** fires the bakeoff memo's "no provider clears
the bar yet" branch:

- NomadFi stays on FinanceKit + manual + CSV.
- The Plaid scaffolding stays inactive in production builds.
- Re-evaluation is gated on a regulator/standards shift (CFPB 1033
  operationalization, Canada's Consumer-Driven Banking regime
  publishing developer-accessible endpoints) or material FinanceKit
  Canadian coverage expansion.
- An Akoya sandbox comparison only starts if there is an explicit
  primary-source reason to believe Akoya's Canadian coverage or
  production onboarding differs meaningfully — not "let's try
  another vendor" by default.

A live-data **inconclusive** result (e.g. the chosen FI was
unavailable in Plaid Link, or Plaid Limited Production caps blocked
the connection) doesn't fire the fail branch but doesn't resolve
criterion 5 either. Document the run, retry against a different FI
in the Canadian shortlist, and only escalate after a second
inconclusive.

---

## 6. Reminder: one sandbox run is not criterion 5

The sandbox plumbing run on April 24, 2026 proved the iOS + broker
+ LinkKit + reconciler plumbing on a physical iPhone. It cannot
prove real Canadian-FI coverage because Plaid Sandbox uses
pre-defined test institutions and test credentials per
[plaid.com/docs/sandbox/institutions/](https://plaid.com/docs/sandbox/institutions/)
+ [plaid.com/docs/sandbox/test-credentials/](https://plaid.com/docs/sandbox/test-credentials/)
(both vendor-reported). The ONLY way criterion 5 resolves is the
runbook in §4 above, with §1 fully completed first.

---

## 7. What is explicitly out of scope for this preflight

- Production multi-user onboarding (this is a **single-developer
  evaluation**, not a rollout).
- Webhooks, scheduled syncs, or background-delivery hardening.
- Billing / invoicing (sandbox runs are free; live-data runs may
  incur Plaid Limited Production charges per Plaid's pricing page —
  vendor-reported, not modelled here).
- Akoya / MX / Mastercard-Finicity / direct FDX. Out of scope for
  this slice; the bakeoff memo's "no provider clears the bar yet"
  branch is the gate to revisit them.
- Tax / investing education work.

---

## 8. Primary sources

- [Plaid API overview](https://plaid.com/docs/api/) (vendor-reported
  on environments + Production access).
- [Plaid Sandbox](https://plaid.com/docs/sandbox/) (vendor-reported
  on sandbox semantics + test institutions).
- [Plaid Sandbox institutions](https://plaid.com/docs/sandbox/institutions/).
- [Plaid Link iOS](https://plaid.com/docs/link/ios/).
- [Plaid Link OAuth](https://plaid.com/docs/link/oauth/).
- [Plaid in Canada](https://plaid.com/en-ca/) (vendor-reported
  Canadian coverage).
- [Apple Universal Links](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html).
