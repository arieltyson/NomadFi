# FinanceKit Feasibility — Phase 5C Research Dossier

This document records what NomadFi can and cannot do with Apple's
FinanceKit framework today, based on official Apple documentation and
the locally-installed Xcode 26.4 SDK. It is a working operational
reference, not marketing copy.

It should stay factual and narrow. Where no official source exists for
a claim, say so and fall back to the SDK surface or to other first-
party references (e.g. CFPB 1033, FDX) rather than to vendor blogs.

---

## 1. What FinanceKit is

FinanceKit is an Apple-only framework introduced in iOS 17.4 that
exposes the user's on-device Wallet financial data — Apple Card, Apple
Cash, Apple Savings, and a growing set of supported open-banking
institutions — to a consenting app. Data stays on-device; Apple does
not receive the queries or results.

- Framework: `FinanceKit`
- Primary class: `FinanceStore` (singleton via `FinanceStore.shared`)
- First platforms: iOS 17.4, iPadOS 17.4 (device access),
  iOS 17 for the Orders-only subset.
- Availability on macOS, tvOS, watchOS, visionOS,
  Mac Catalyst: **none** (confirmed in the local swiftinterface —
  every data-access API is marked
  `@available(tvOS/macOS/watchOS/visionOS/macCatalyst, unavailable)`).

Source reading this dossier relies on:

- [`developer.apple.com/documentation/financekit`](https://developer.apple.com/documentation/financekit)
- [`developer.apple.com/financekit/`](https://developer.apple.com/financekit/)
- Local swiftinterface:
  `Xcode.app/.../iPhoneSimulator26.4.sdk/System/Library/Frameworks/FinanceKit.framework/Modules/FinanceKit.swiftmodule/*.swiftinterface`

---

## 2. Eligibility and entitlement

FinanceKit's financial-data surface is gated behind a **managed
entitlement**. Apple calls this out on
[`developer.apple.com/financekit/`](https://developer.apple.com/financekit/)
and in the framework's onboarding material.

- Entitlement key: `com.apple.developer.financekit`
- Entitlement value: `["financial-data"]` (array of strings)
  — for the financial-data / transactions / balances surface.
- Info.plist key: `NSFinancialDataUsageDescription` — required purpose
  string that appears in the consent prompt. (Already present in
  NomadFi's Xcode project build settings for both Debug and Release.)

Apple's current gating:

1. The app's developer account must **request** the FinanceKit
   capability from Apple. The capability is reviewed per bundle
   identifier, not per developer account.
2. The app should be distributed through the App Store (not TestFlight
   in arbitrary regions) in a finance-relevant category.
3. The user must grant consent through the system authorization
   sheet. The sheet uses the `NSFinancialDataUsageDescription` copy
   as the rationale.

**Hard blockers outside the code:**

- Apple provisioning of `com.apple.developer.financekit`. NomadFi
  cannot call `FinanceStore.shared.accounts(query:)` on a real device
  without it.
- App Store category / review. Apple expects to see a finance-category
  app before granting the capability.
- Per-account eligibility on the user's side — a user who does not
  hold any FinanceKit-eligible account (no Apple Card, Apple Cash,
  Apple Savings, or supported UK open-banking link) will authorize
  and then see an empty `accounts(query:)` result. NomadFi must
  handle this without implying the user's other institutions are
  "not connected" — they were never in scope.

---

## 3. Supported coverage (authoritative summary)

Official Apple coverage statements, paraphrased from
[`developer.apple.com/financekit/`](https://developer.apple.com/financekit/)
and release notes:

- **United States**: Apple Card, Apple Cash, Apple Savings.
- **United Kingdom**: a set of supported open-banking institutions
  surfaced through Apple Wallet. The list evolves; treat
  `accounts(query:)` as the authoritative source on a given device.
- **No general support** for arbitrary banks in either region, nor
  for any other region in the public framework today.

There is no peer-reviewed evidence that FinanceKit gives broad market
coverage. The only authoritative list is the live
`accounts(query:)` result on the user's device. NomadFi must not
present a pre-computed institution list or claim coverage beyond what
Apple returns.

---

## 4. API surface NomadFi can call

From the local swiftinterface, the relevant APIs are:

| API | Available | Notes |
|---|---|---|
| `FinanceStore.isDataAvailable(.financialData) -> Bool` | iOS 17 | Device / platform gate. Synchronous. |
| `FinanceStore.shared.authorizationStatus() async throws` | iOS 17.4 | Throws `FinanceError.dataRestricted` when entitlement is missing or blocked. |
| `FinanceStore.shared.requestAuthorization() async throws` | iOS 17.4 | Triggers the system consent sheet. Must be called in response to explicit user action. |
| `FinanceStore.shared.accounts(query: AccountQuery) async throws` | iOS 17.4 | Returns `[Account]` (enum of `.asset` / `.liability`). |
| `FinanceStore.shared.accountBalances(query: AccountBalanceQuery) async throws` | iOS 17.4 | Returns `[AccountBalance]` with `.available` / `.booked` / `.availableAndBooked` current balance shapes. |
| `FinanceStore.shared.transactions(query: TransactionQuery) async throws` | iOS 17.4 | Returns `[Transaction]`; supports `#Predicate` filters on `accountID`, `transactionDate`, status, type, MCC. |
| `accountHistory(since:isMonitoring:)` / `accountBalanceHistory(forAccountID:since:)` / `transactionHistory(forAccountID:since:)` | iOS 17.4 | Async sequences for incremental change delivery (token-based). |
| `enableBackgroundDelivery(for:frequency:)` | iOS 26.0 | Requires a `BackgroundDeliveryExtension` app extension. |

NomadFi's Phase 5C adapter calls the three `query:` APIs. History
sequences and background delivery are declared as seams but not
enabled — they require more entitlement and target work.

---

## 5. NomadFi product surfaces that benefit first

Once Apple provisions the entitlement and the adapter runs against
real data, the reconciler (Phase 5B) writes into the existing
`Account` / `Transaction` store. Downstream surfaces benefit without
fork:

1. **Dashboard** — `SpendingTrendComputer`, `InsightEngine`, and the
   net-worth readout all consume `Account` / `Transaction` rows with
   `FinancialSnapshotSource`-driven freshness. New FinanceKit rows
   appear here automatically.
2. **Credit Timing Decision** —
   `CreditTimingDecisionEngine` reads `creditLimit`,
   `currentBalance`, `availableCredit`, and `statementBalance` on
   each `Account`. Fresh FinanceKit balances shorten the staleness
   window that currently gates readiness rulings.
3. **Purchase Decision** — `PurchaseDecisionEngine` uses the same
   balance / limit / statement fields plus verified reward profiles.
   FinanceKit does not supply reward terms; those stay user-entered.

---

## 6. What FinanceKit does **not** solve

- **Universal institution coverage.** Apple never promised it and
  `accounts(query:)` never returns it.
- **FX / tax / investment advice.** The transaction payload carries
  `foreignCurrencyAmount` and `foreignCurrencyExchangeRate` (iOS 18+)
  but nothing tax-relevant. NomadFi keeps FX provenance and tax
  classification in its own layer.
- **Reward terms.** Not in the `LiabilityAccount.creditInformation`
  payload. NomadFi's `RewardProfile` stays user-entered / verified.
- **Credit-score prediction.** FinanceKit exposes credit limit,
  minimum next payment, and overdue payment — not a FICO / VantageScore
  value. NomadFi must never imply otherwise.
- **Statement-period metadata beyond payment due date.** The framework
  does not expose statement period start / end dates on the public
  API on this SDK. NomadFi's credit-card schedule stays user-entered.
- **Recurring-charge inference or merchant normalization.** NomadFi
  runs its own `RecurringChargeDetector` and `MerchantNormalizer`
  over the reconciled rows.

---

## 7. Error / state matrix

Every `async throws` FinanceKit call in this SDK can raise
`FinanceError.dataRestricted(DataType)` when the managed entitlement is
absent or the system has blocked access. `FinanceError.unknown` covers
all other framework failures. iOS 18+ adds
`FinanceError.historyTokenInvalid` for incremental change delivery.

The provider adapter distinguishes:

| Surface | Code path |
|---|---|
| Not supported on platform / device | `FinanceStore.isDataAvailable(.financialData) == false` → `.unavailable(.notSupportedOnDevice)` |
| Entitlement not provisioned / restricted | `FinanceError.dataRestricted` → `.unavailable(.entitlementNotProvisioned)` |
| Authorization not determined | `AuthorizationStatus.notDetermined` → `.notDetermined` |
| Authorization denied | `AuthorizationStatus.denied` → `.denied` |
| Authorized, no eligible accounts | `.authorized` + `accounts(query:)` returns `[]` → Settings row reads "Authorized — no eligible accounts found" |
| Refresh failed (network / unknown) | `FinanceError.unknown` or non-`FinanceError` → `.refreshFailed` |

Copy guarantees:

- Never say "all your banks" / "every institution" / "connected to
  every account".
- Never imply Apple sees the data.
- Surface the zero-accounts state explicitly rather than silently
  looking identical to "not configured".

---

## 8. Real-device test matrix

A bakeout on a supported device must cover each row before Phase 5D
can begin.

| Scenario | Expected Settings status row | Expected reconciler result |
|---|---|---|
| Device does not support FinanceKit (e.g. iPad on some regions) | "Not available on this device" | No-op; manual and CSV providers remain usable |
| Device supports FinanceKit, entitlement not granted | "Available on supported devices" | No-op; adapter throws `.providerUnavailable(.entitlementNotProvisioned)` |
| Entitlement granted, not authorized | "Authorization required" | Sync skipped for this provider |
| Entitlement granted, authorization denied | "Authorization required" | Sync skipped |
| Authorized, user holds **no** Apple Card / Apple Cash / Apple Savings / UK-linked account | "Authorized — no eligible accounts found" | No accounts created, no transactions inserted, no failure counted |
| Authorized, holds Apple Card only | "Connected" + last-synced date | One credit-card Account (liability) with current balance, credit limit, available credit; associated transactions |
| Authorized, holds Apple Cash only | "Connected" + last-synced date | One checking-kind Account (asset); associated transactions |
| Authorized, holds Apple Savings + Apple Card | "Connected" + last-synced date | Two accounts, each mapped per kind |
| Sync while offline | "Connected" (last-synced date unchanged) | `skippedUnavailable` or `refreshFailed` outcome — no duplicate / lost rows |
| Authorization revoked in system Settings after an earlier successful sync | "Authorization required" | Sync skipped; previously-reconciled rows stay on device |
| UK open-banking account added after initial authorization | "Connected" with updated counts | New account reconciled via durable identity or fallback — no duplicate created |

Each row has a deterministic test case in
`FinancialDataReconcilerTests.swift` or
`FinancialConnectionsViewModelTests.swift` except those requiring a
real device + real Apple account.

---

## 9. Entitlement wiring decision (Phase 5C)

**Decision: do not add `com.apple.developer.financekit` to
`NomadFi/NomadFi.entitlements` in this slice.**

Rationale:

- The entitlement is **managed**. Adding it to the entitlements file
  before Apple has provisioned the capability on the app's bundle
  identifier (`com.arieljtyson.NomadFi`) causes automatic-signing
  warnings on real-device builds and can cause the entitlement to be
  stripped at install, which looks identical to "entitlement
  provisioned but framework returning zero accounts" — a confusing
  failure mode.
- On the iOS simulator the FinanceKit data class is not available at
  all (`FinanceStore.isDataAvailable(.financialData) == false`).
  Wiring the entitlement does not enable any new behavior there.
- NomadFi's adapter already fails gracefully when the entitlement is
  absent (`.unavailable(reason: .entitlementNotProvisioned)` status
  and a calm Settings row).

**Manual provisioning steps to run before Phase 5D:**

1. Apple Developer → Certificates, Identifiers & Profiles → the
   `com.arieljtyson.NomadFi` identifier → **Request additional
   capability** → **FinanceKit**. Fill out the intended data-access
   rationale using the same copy as `NSFinancialDataUsageDescription`.
2. After Apple approves the capability (typically days; involves
   Apple-side review of the intended use case), add the entitlement
   to `NomadFi/NomadFi.entitlements`:
   ```xml
   <key>com.apple.developer.financekit</key>
   <array>
       <string>financial-data</string>
   </array>
   ```
3. Regenerate provisioning profiles (automatic signing handles this
   once the capability is attached to the App ID).
4. Verify on a supported real device (iPhone running iOS 17.4 or later
   with at least one FinanceKit-eligible account) that
   `FinanceStore.isDataAvailable(.financialData)` returns `true` and
   `FinanceStore.shared.requestAuthorization()` surfaces the system
   consent sheet with NomadFi's purpose string.

Until step 1 completes, the adapter remains at `.unavailable(reason:
.entitlementNotProvisioned)` on real devices — consistent with the
Settings page copy "Available on supported devices".

---

## 10. Go / no-go criteria for advancing to Phase 5D

Phase 5D is explicitly framed as a **provider bakeoff**, not an
assumed Plaid integration. Phase 5C is done; Phase 5D can start once
**all** of the following are true:

- [ ] Apple has provisioned `com.apple.developer.financekit` on the
  `com.arieljtyson.NomadFi` identifier.
- [ ] The adapter has been exercised on a real supported device across
  at least the first six scenarios in the test matrix above and has
  passed without crash, without duplicate row creation, and without
  silently dropping a mapped row.
- [ ] The real-device bakeout confirms that
  `FinanceKitSnapshotMapper.mapAccount` and `mapTransaction`
  correctly handle `FinanceKit.CurrencyAmount` / `CreditDebitIndicator`
  / `TransactionStatus` values that do not appear in unit-test
  fixtures (in particular: non-USD currencies and the
  `.availableAndBooked` balance case).
- [ ] A short written note confirms what product surfaces *actually*
  benefit from FinanceKit with the tester's real portfolio — or
  confirms that FinanceKit alone is insufficient and a third-party
  aggregator provider is the next necessary step.

If FinanceKit alone proves insufficient (high-confidence outcome,
given its narrow coverage), Phase 5D becomes:

- Research third-party aggregator options against explicit criteria:
  coverage per NomadFi's home jurisdictions (US / Canada / UK / TT),
  consent model alignment with CFPB 1033 / FDX, SDK footprint,
  privacy posture (does the SDK phone home?), cost, and revocation
  UX.
- Prototype an adapter behind the existing
  `ExternalAggregatorFinancialDataProvider` seam; do not replace any
  existing provider.
- Keep vendor SDK imports confined to the adapter file. NomadFi's
  core domain model must remain vendor-neutral.

Until those conditions are met, the Decision Assistant keeps working
from manual and CSV truth. That is the point of the provider-neutral
architecture shipped in Phase 5A / 5B.
