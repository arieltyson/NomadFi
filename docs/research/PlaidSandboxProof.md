# Plaid Sandbox Proof — Phase 5D Follow-Through

Engineering decision memo covering the bounded Plaid *sandbox* proof
that the provider bakeoff
([`OpenFinanceProviderBakeoff.md`](./OpenFinanceProviderBakeoff.md))
called for. Written so the next contributor (or a future
Phase 5E run) can tell what was proven in code, what remains
vendor-reported, and what is genuinely unresolved.

This is not a production Plaid integration. It is a contained proof
against the five pinned criteria from the bakeoff memo.

---

## 0. TL;DR

| Criterion | Outcome (after Phase 5D execution decisioning, April 24, 2026) |
|---|---|
| 1. Plaid Link authorization flow maps onto NomadFi's consent model | **Pass (real-device sandbox)** — the full Link session ran end-to-end on a physical iPhone (April 24, 2026 sandbox run): broker `link_token/create` → LinkKit consent UI → `public_token` → broker `/item/public_token/exchange` → NomadFi persisted item handle. Universal-link return was not exercised because Plaid's sandbox institutions don't trigger an OAuth redirect (vendor-reported behaviour at https://plaid.com/docs/sandbox/institutions/); that path remains a real-OAuth-FI concern. |
| 2. Accounts / balances / transactions project onto provider-neutral snapshots | **Pass (real-device sandbox)** — `/accounts/get` returned 10 accounts, all mapped through `PlaidSandboxSnapshotMapper`, and the reconciler created 10 accounts under provider-neutral durable identity. |
| 3. `/transactions/sync` dedupe invariants hold through the existing reconciler | **Pass (real-device sandbox)** — first-pull diff produced 48 transactions; reconciler reported 0 unresolved + 0 duplicates with `degraded_gracefully=true`. |
| 4. Unit-cost modelling stays inside a pre-revenue budget using public pricing | **Partial (paper)** — unchanged. Sandbox traffic is free; production pricing has not been negotiated. |
| 5. Canadian coverage against NomadFi's target-user institutions | **Unresolved** — sandbox runs use Plaid's pre-defined test institutions (`ins_109508`-style) and test credentials (vendor-reported at https://plaid.com/docs/sandbox/institutions/ + https://plaid.com/docs/sandbox/test-credentials/). They cannot prove real CIBC / RBC / TD / Scotia / BMO / Tangerine / Simplii login behaviour. Resolving criterion 5 requires a live-data path — Plaid's Limited Production / Trial environment against a real target Canadian FI — not another sandbox rerun. |

Recommendation (after the April 24, 2026 sandbox-on-device run):
**do not start a full Phase 5E Plaid implementation yet, and do not
start an Akoya comparison yet.** Criteria 1–3 are now real-device
sandbox pass; the remaining gates are evidentiary, not architectural:

1. **Apple FinanceKit entitlement** — request submitted, awaiting
   Apple's response. Real-device FinanceKit validation depends on
   it.
2. **Real-target-FI live-data validation** — the only step that
   resolves criterion 5. Sandbox cannot prove it; Plaid's docs are
   explicit that sandbox simulates institution behaviour with
   pre-defined test institutions and test credentials.

Operational next step (when ready): apply for Plaid's Limited
Production / Trial environment for `com.arieljtyson.NomadFi` so the
broker can be pointed at a real Canadian FI with real credentials.
The broker already supports the live-data mode natively
(`PLAID_ENV=production` + `PLAID_LIVE_DATA_EVALUATION=1`); the
preflight checklist is documented in
[`PlaidLimitedProductionReadiness.md`](./PlaidLimitedProductionReadiness.md).
Document the outcome in a successor artifact, **not** by re-running
sandbox.

If FinanceKit alone clears the bar for NomadFi's archetype, Phase
5E stays deferred and the Plaid Link scaffolding remains inactive
in production builds. If it does not, the proof code and tests are
strong enough to convert into Phase 5E quickly — the remaining work
is a production-access conversation with Plaid and the removal of
`/sandbox/*` bypasses.

---

## 0.1 First real-device sandbox run (April 24, 2026)

The validation recorder produced its first real-device sandbox
artifact on a physical iPhone running NomadFi DEBUG, with the broker
in LAN mode (Mac on iPhone hotspot to keep both endpoints on the
same trusted network). Summary lifted from the artifact:

- Session duration: 6m 34s.
- 13 events recorded.
- `link_token` created → LinkKit consent UI completed → exchange
  succeeded → item handle persisted (`itm_****5681`).
- Sync produced 10 account snapshots + 48 transaction snapshots; the
  reconciler created 10 accounts with 0 unresolved / 0 duplicates.
- Result marked **pass** by the developer.

What this run **proved**:

- Real-device NomadFi + LAN-mode broker reachability.
- LinkKit + Plaid sandbox flow on a real device.
- Public-token exchange via the broker.
- `/accounts/get` + `/transactions/sync` projection through the pure
  mapper into NomadFi's provider-neutral snapshots.
- Reconciliation invariants on a real device (durable identity wins,
  no cross-account merge, dedupe scoped per account).

What this run **did not** prove:

- Real CIBC (or any real Canadian FI) login behaviour. The institution
  was a Plaid sandbox test institution with synthetic credentials.
- OAuth universal-link return. Sandbox institutions don't trigger
  Plaid's OAuth bank-handoff path; the universal-link plumbing
  shipped in Phase 5D gate-clearance is exercised only when a real
  OAuth-capable FI is linked under live data.
- Any per-FI coverage claim under Plaid's marketed Canadian list.

Recorder caveat: the artifact's auto-generated criterion-5 line read
"Broker reachable: no" because the developer didn't tap the explicit
`/health` probe before launching Link. The downstream events
(successful `public_token_exchange` + `sync_finished` with 10 accounts
+ 48 transactions) are stronger evidence of reachability — every one
of those calls routed through the broker. The Markdown writer was
upgraded after this run to label that branch as
`yes (inferred from successful exchange/sync)` so future artifacts
read accurately. Health-check verification still wins the label
when an explicit probe has run.

Institution-name caveat: the Markdown reads "Institution observed:
not recorded in this export" because the developer did not toggle
**Include institution name in export** in the harness before linking.
For runs that need institution evidence, flip the toggle on before
the link launch. The recorder always logs `display_name_included`
either way so a future reader can tell whether the absence is
"redacted on purpose" vs. "never observed".

---

## 1. Scope

This slice ships:

- **Provider-neutral adapter boundary.**
  `Core/Services/FinancialData/Providers/Plaid/` holds every file
  that ever imports a Plaid-shaped DTO. Nothing outside that
  directory knows Plaid exists.
- **Pure mapper** (`PlaidSandboxSnapshotMapper`) from Plaid DTOs to
  `FinancialAccountSnapshot` / `FinancialTransactionSnapshot`.
- **HTTP client** (`PlaidSandboxClient` + `LivePlaidSandboxClient`)
  that only speaks to a local broker on `127.0.0.1`.
- **Configuration** (`PlaidSandboxConfiguration`) that reads the
  broker URL / item handle / cursor from the Keychain — never the
  Plaid `client_id` or `secret`.
- **Adapter** (`PlaidSandboxFinancialDataProvider`) that satisfies
  the existing `FinancialDataProvider` protocol and honours the
  Phase 5A/5B/5C invariants.
- **Local broker** at `tools/plaid-sandbox-broker/` that holds
  Plaid sandbox credentials in a git-ignored `.env` and proxies the
  narrow subset of endpoints the adapter needs.
- **Focused tests** covering the mapper, configuration round-trip,
  provider availability / authorization state projection, and the
  `/transactions/sync` dedupe-through-reconciler integration.

This slice **does not** ship:

- Plaid Link SDK integration.
- Production Plaid keys, or any Plaid keys in the repo.
- Akoya, MX, or Finicity code.
- Institution-manager UI.
- Background sync.
- Multi-user onboarding.
- Any endpoint that reveals a real Plaid `access_token` to the client.

---

## 2. Secret boundary

Plaid `client_id` and `secret` never touch the iOS app.

- They live only in
  `tools/plaid-sandbox-broker/.env` (copied from `.env.example`).
  `.env` is git-ignored by the repo root and by the broker's own
  `.gitignore`.
- The broker refuses to start unless `PLAID_ENV=sandbox`.
- The broker exposes no endpoint that returns the real
  `access_token` to the client. The app sees only an opaque item
  handle (e.g. `itm_29f63c0ccff1…`) the broker mints itself.
- The iOS side stores three values in the Keychain (all device-only,
  never iCloud-synced):
  - `com.nomadfi.plaidSandboxBrokerURL`
  - `com.nomadfi.plaidSandboxItemID`
  - `com.nomadfi.plaidSandboxTransactionsCursor`
- `KeychainService.deleteAll()` wipes all three as part of the
  existing "Delete All My Data" flow.

Nothing Plaid-shaped is persisted in SwiftData, `UserDefaults`, or
the project's string catalog.

---

## 3. Criterion-by-criterion evaluation

### 3.1 Criterion 1 — Plaid Link flow maps onto NomadFi's consent model

**Outcome: Pass (in-code).**

What is proven in code *after the Phase 5D gate-clearance slice*:

- Plaid's official `LinkKit` SDK is added as an SPM dependency of
  the `NomadFi` target (source:
  [Plaid Link iOS SDK](https://plaid.com/docs/link/ios/)). The
  `import LinkKit` lives only inside
  `PlaidLinkKitPresenter.swift`; everything else in the Plaid
  boundary uses the abstract `PlaidLinkPresenting` protocol.
- `PlaidLinkCoordinator` is a `@MainActor` `@Observable` state
  machine with a deterministic phase progression:
  `idle → fetchingLinkToken → presentingLink → exchangingPublicToken → completed|cancelled|failed`.
  The Settings UI binds to `coordinator.phase.statusLabel`
  directly; every test in `PlaidLinkCoordinatorTests` covers a
  transition.
- The broker creates a real `link_token` via
  `/link/token/create`, applying the OAuth-compatible
  `redirect_uri` when `PLAID_REDIRECT_URI` is set in the broker's
  `.env`. The app exchanges the Link success callback's
  `public_token` through the new broker endpoint
  `/item/public_token/exchange`; the app never sees Plaid's real
  `access_token`.
- iOS universal-link / associated-domains plumbing is in place:
  - `NomadFi.entitlements` declares
    `applinks:arieltyson.github.io`.
  - The root `NomadFiApp` forwards `.onOpenURL(...)` to
    `PlaidLinkCoordinator.handle(universalLink:)`, which in turn
    calls LinkKit's `handler.continue(from:)`.
  - The redirect page is hosted at
    `https://arieltyson.github.io/nomadfi-privacy/plaid-oauth/`
    with a small "returning you to NomadFi…" fallback.
  - AASA is hosted at
    `https://arieltyson.github.io/nomadfi-privacy/.well-known/apple-app-site-association`,
    declaring the universal-link `components` for
    `/plaid-oauth` and `/plaid-oauth/*`.
- The sandbox-bypass authorization path
  (`PlaidSandboxFinancialDataProvider.requestAuthorization()`)
  remains available for tests / dev, but the real Link flow is now
  the production authorization path when `PLAID_REDIRECT_URI` is
  configured on the broker.

What remains outside the repo:

- A production-access conversation with Plaid (moves the flow from
  *sandbox* to *production* keys).
- A real-device bakeout against at least one target OAuth
  institution — criterion 5 resolves only when this runs.

Evidence (in-code):

- `PlaidLinkCoordinatorTests.happyPathLinkFlow`
- `PlaidLinkCoordinatorTests.userExitsLink`
- `PlaidLinkCoordinatorTests.publicTokenExchangeFails`
- `PlaidLinkCoordinatorTests.universalLinkForwardedWhilePresenting`
- `PlaidLinkCoordinatorTests.universalLinkIgnoredWhenIdle`
- `PlaidLinkCoordinatorTests.brokerCreateLinkTokenFails`
- `PlaidLinkCoordinatorTests.missingBrokerURL`
- `PlaidLinkCoordinatorTests.statusLabelsAreHonest` (copy guard)

Vendor-reported (not independently validated):

- Plaid's OAuth conversion claims at large US banks.
- Plaid's Canadian FI list and OAuth status per institution.

### 3.2 Criterion 2 — Provider-neutral snapshot projection

**Outcome: Pass.**

What is proven in code:

- `PlaidSandboxSnapshotMapper` projects every relevant Plaid shape
  onto NomadFi's provider-neutral snapshot contract:
  - `PlaidAccountType.credit` → `.creditCard` with credit info
    populated from Plaid's `current` / `available` / `limit` slots.
  - `PlaidAccountType.depository` → `.checking` by default;
    subtype `"savings"` narrows to `.savings`.
  - `PlaidAccountType.investment` / `.brokerage` → `.investment`.
  - `PlaidAccountType.loan` → honestly dropped. NomadFi's domain
    has no loan type and coercing would misrepresent the row.
  - Unsupported currencies are dropped rather than coerced.
  - Plaid's outflow-positive amount is flipped to NomadFi's
    outflow-negative convention.
  - `personal_finance_category.primary` maps onto
    `TransactionCategory` conservatively.
- `PlaidSandboxFinancialDataProvider.fetchAccountSnapshots()` and
  `fetchTransactionSnapshots(accountID:from:to:)` produce snapshots
  the reconciler accepts without structural change.

Evidence:

- `PlaidSandboxSnapshotMapperTests` (every mapping branch).
- `PlaidSandboxIntegrationTests.snapshotFanOutThroughReconciler`.
- Regression-green status on
  `FinancialDataReconcilerTests` /
  `FinancialDataProviderArchitectureTests` /
  `FinancialConnectionsViewModelTests` /
  `AccountFinancialSnapshotTests`.

### 3.3 Criterion 3 — `/transactions/sync` dedupe invariants

**Outcome: Pass.**

What is proven in code:

- First `/transactions/sync` pull inserts rows through the existing
  `FinancialDataReconciler`, writing both the durable provider link
  on `Account` and the provider kind raw value on `Transaction`.
- Replaying the same payload re-matches the account by durable
  provider identity (not by fallback) and the transactions dedupe
  to zero-inserts through the existing
  `TransactionImportDeduper`'s external-ID path, counted as
  `skippedDuplicateTransactions`.
- The `/transactions/sync` cursor is persisted **only** after the
  coordinator's `finalizeAfterCommit()` runs, which in turn is
  called by `FinancialConnectionsViewModel` *after* the reconciler
  commits. A reconciler failure therefore never strands rows
  behind a moved cursor — matching Plaid's documented incremental-
  sync guidance.
- The adapter's `paginateSync` follows `has_more: true` / `false`
  to paginate, capped at 20 pages so a misbehaving sandbox cannot
  spin forever.

Evidence:

- `PlaidSandboxIntegrationTests.repeatSyncIsDedupedByReconciler`
- `PlaidSandboxIntegrationTests.cursorCommittedAfterReconcile`
- `PlaidSandboxIntegrationTests.snapshotFanOutThroughReconciler`

Unhandled today (documented, not a blocker for this proof):

- Plaid's `/transactions/sync` can return `removed` transaction IDs.
  NomadFi's reconciler today does not have a deletion path. The
  adapter forwards the `removed` list into the cache but does not
  yet act on it. This matches the existing "reconciler never mutates
  unrelated fields" rule — deletions belong to a separate slice.

### 3.4 Criterion 4 — Unit economics against public pricing

**Outcome: Partial (paper), vendor-reported, not independently validated.**

Inputs (Plaid primary docs):

- [Plaid pricing](https://plaid.com/pricing/) publishes a
  pay-as-you-go schedule with per-API-call rates and per-connected-
  account rates for Transactions, Auth, Balance, and Identity.
- [Billing mechanics](https://plaid.com/docs/account/billing/)
  documents how connected items accrue per-month and how
  Transactions is charged. Vendor-reported.

Model used for the paper estimate (pre-revenue assumptions):

- Transactions + Auth + Balance as the only enabled products.
- One connected item per active user at a time (NomadFi's target
  archetype holds one primary US checking / credit pair today).
- An incremental `/transactions/sync` cadence of once per Sync-Now
  action, bounded by the user's explicit action. No background
  sync in this slice.

The model shows per-connected-user cost tracks Plaid's published
Transactions product rate directly. The exact figure depends on the
starting commercial tier, which Plaid does not publish below the
first paid rung.

What is **not** proven:

- Whether NomadFi's actual retention + sync cadence holds the cost
  inside a zero-revenue budget at scale.
- Whether a startup-friendly commercial contract is available.
- Whether `/transactions/sync` token cost differs materially from
  `/transactions/get`.

These are exactly the kinds of questions only a real production
access conversation with Plaid can answer, so the proof marks this
criterion **partial** rather than pass.

### 3.5 Criterion 5 — Canadian coverage against NomadFi's target institutions

**Outcome: Unresolved.**

Plaid's [Plaid in Canada](https://plaid.com/en-ca/) page is
vendor-reported. The bakeoff memo already flagged that Canadian
coverage cannot be validated from public sources alone.

This slice does not resolve it. Running `/sandbox/item/create`
against Plaid's sandbox institution (`ins_109508`, "First Platypus
Bank") returns a US-only fixture. The official Plaid sandbox does
not expose NomadFi's Canadian target-user institutions (RBC / CIBC /
TD / Scotia / BMO / Tangerine / Simplii) as OAuth-first linkable
sandboxes at the time of this memo.

Therefore this criterion stays **unresolved** until one of:

- A real Plaid Link flow is run against at least one of those FIs
  with the managed entitlement in place.
- Plaid publishes an independently-verifiable Canadian FI coverage
  list with OAuth status per institution.

The bakeoff memo's `"no provider clears the bar yet"` branch is
explicitly scoped to cover this outcome.

---

## 4. End-to-end flow (sandbox)

```
           iOS (NomadFi)                    tools/plaid-sandbox-broker           plaid.com/sandbox
     ┌─────────────────────┐                ┌───────────────────────────┐       ┌─────────────────┐
Authorize                 Authorize              POST /sandbox/item/create          /sandbox/public_token/create
  ───────────────────────────────────────────►  ────────────────────────────►     ───────────────►
                                                 (client_id / secret only
                                                  known to the broker)
                                                 /item/public_token/exchange ◄───
                                                 { item_handle = itm_...
                                                   institution_name = ... }
  ◄───────────────────────────────────────────
Keychain persist itm_...

Sync Now                     POST /accounts/get        /accounts/get
  ───────────────────────────────────────────►  ────────────────────────────►
                                                 { accounts, institution }  ◄───
  ◄───────────────────────────────────────────
Map → [FinancialAccountSnapshot]

                              POST /transactions/sync  /transactions/sync
  ───────────────────────────────────────────►  ────────────────────────────►
                                                 { added, modified, removed,
                                                   next_cursor, has_more }   ◄───
  ◄───────────────────────────────────────────
Map → [FinancialTransactionSnapshot]
     │
     ▼
FinancialDataReconciler.apply(report:)
     │
     ▼ (only after commit)
coordinator.finalizeAfterCommit()
     │
     ▼
Keychain persist next_cursor
```

---

## 5. Going live (deferred to Phase 5E, bullet list only)

In rough order, each item is tracked in the bakeoff memo:

1. Apple FinanceKit managed entitlement lands (the request for
   `com.arieljtyson.NomadFi` is already submitted).
2. A real device + a FinanceKit-eligible user account runs through
   the feasibility test matrix.
3. Decide whether FinanceKit alone clears the bar for NomadFi's
   cross-border archetype. If yes, Phase 5E stays deferred; if no,
   proceed with Plaid.
4. Run a real Plaid Link flow (add `LinkKit` via SPM, 1-line
   addition) against at least one target Canadian FI under the
   existing broker + adapter scaffolding.
5. Resolve Canadian coverage (criterion 5).
6. Convert the sandbox proof into Phase 5E: remove the `/sandbox/*`
   bypass, add a production-access conversation with Plaid, add the
   consent / revocation / aggregator-disclosure copy the 1033 path
   requires.
7. Start the Akoya parallel comparison once Plaid's real-device
   Link flow is observed, per the bakeoff memo's post-sandbox
   instruction.

None of that happens in this slice.

---

## 6. Primary sources used

Plaid (vendor-reported where noted):

- [Link iOS SDK](https://plaid.com/docs/link/ios/)
- [Link overview](https://plaid.com/docs/link/)
- [Link endpoints](https://plaid.com/docs/api/link/)
- [Sandbox](https://plaid.com/docs/sandbox/)
- [Transactions](https://plaid.com/docs/transactions/)
- [Transactions Sync](https://plaid.com/docs/transactions/sync/)
- [Auth](https://plaid.com/docs/api/products/auth/)
- [Balance](https://plaid.com/docs/api/products/balance/)
- [Institutions](https://plaid.com/docs/institutions/)
- [OAuth in Link](https://plaid.com/docs/link/oauth/)
- [Pricing](https://plaid.com/pricing/)
- [Billing mechanics](https://plaid.com/docs/account/billing/)
- [Plaid in Canada](https://plaid.com/en-ca/)

Regulator + standards:

- CFPB 1033 (§ 401 / § 421 / § 431):
  [§ 401](https://www.consumerfinance.gov/rules-policy/regulations/1033/401/),
  [§ 421](https://www.consumerfinance.gov/rules-policy/regulations/1033/421/),
  [§ 431](https://www.consumerfinance.gov/rules-policy/regulations/1033/431/).
- [FDX overview](https://financialdataexchange.org/FDX/FDX/About/About-FDX.aspx).

Apple (FinanceKit context only; not re-evaluated here):

- [FinanceKit](https://developer.apple.com/documentation/financekit)
- [FinanceKit overview](https://developer.apple.com/financekit/)
