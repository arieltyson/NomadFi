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

| Criterion | Outcome |
|---|---|
| 1. Plaid Link authorization flow maps onto NomadFi's consent model | **Partial** — architectural mapping is shipped in code and tested; the Link SDK UI itself is deferred (sandbox-bypass item creation stands in). |
| 2. Accounts / balances / transactions project onto provider-neutral snapshots | **Pass** — pure mapper + adapter composition both covered. |
| 3. `/transactions/sync` dedupe invariants hold through the existing reconciler | **Pass** — end-to-end test covers first-pull insert, repeat-pull dedupe, cursor commit only after reconciler write. |
| 4. Unit-cost modelling stays inside a pre-revenue budget using public pricing | **Partial (paper)** — modelled from Plaid's public pricing page; no commercial contract validation. |
| 5. Canadian coverage against NomadFi's target-user institutions | **Unresolved** — not provable from public docs alone; requires a real Link flow against live Canadian FIs. |

Recommendation: **do not start a full Phase 5E Plaid implementation
yet, and do not start an Akoya comparison yet.** The proof code and
tests are strong enough to let NomadFi land that work quickly once
two gating things happen:

1. The Apple FinanceKit entitlement request lands and real-device
   validation confirms the free-tier coverage.
2. A real Plaid Link flow against at least one target Canadian FI
   resolves criterion 5.

If FinanceKit does not clear its own bar after Apple's response,
Plaid sandbox proof stays on file and the decision is revisited with
Akoya as the first-privacy comparison.

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

**Outcome: Partial (pass on architecture, deferred on UI).**

What is proven in code:

- The adapter satisfies the existing `FinancialDataProvider`
  contract. Its `requestAuthorization()` runs through the broker's
  `/sandbox/item/create` endpoint, which wraps Plaid's documented
  `/sandbox/public_token/create` → `/item/public_token/exchange`
  pair. Once the broker returns an opaque item handle, the adapter
  persists it and moves the Settings row to `.authorized`.
- The provider's availability state machine surfaces four distinct
  user-visible outcomes: `.unavailable(.integrationNotImplemented)`,
  `.availableNoConnections`, `.authorized`, `.denied`. Tested in
  `PlaidSandboxIntegrationTests`.
- The provider uses `FinancialDataProviderKind.externalAggregator(
  identifier: "plaid_sandbox")`. Because this mirrors Phase 5A's
  persistent log key, the link round-trips through
  `FinancialDataProviderKind.fromLogKey(_:)` without a schema
  migration.

What is not yet proven:

- A real Plaid Link SDK consent sheet against a bank's OAuth flow
  has not been exercised. This slice intentionally did not pull the
  Plaid iOS Link SDK package because the proof can test snapshot
  projection and dedupe without it, and adding a vendor SDK without
  exercising it would violate the "no speculative dependencies"
  rule. When Phase 5E lands, adding LinkKit is a one-line SPM
  dependency and a small coordinator that hands the `link_token`
  from `/link/token/create` to `PLKPlaidLinkViewController`. The
  broker endpoint already exists.

Evidence:

- `PlaidSandboxIntegrationTests.noBrokerURLMeansNotImplemented`
- `PlaidSandboxIntegrationTests.brokerConfiguredNoItem`
- `PlaidSandboxIntegrationTests.requestAuthorizationPersistsItemHandle`
- `PlaidSandboxConfigurationTests.logKeyRoundTrip`

Vendor-reported (not independently validated):

- That Plaid Link's OAuth conversion at large US banks exceeds non-
  OAuth flows. Plaid publishes this claim on their own site; no
  peer-reviewed study backs it.

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
