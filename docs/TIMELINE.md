# NomadFi Product Timeline

Phased roadmap for turning NomadFi into a cross-border financial decision
assistant. This document intentionally accounts only for what NomadFi needs to
help users choose payment methods, protect credit leverage, reduce FX waste,
and learn jurisdiction-aware tax and investing concepts; it does not assume
Apple Pay or Wallet should be used just because they are available.

This file is public-safe. It must not duplicate private personal facts from
[`docs/ARIEL.md`](./ARIEL.md).

---

## Mission Anchor

NomadFi helps cross-border students, temporary residents, interns, immigrants,
and other multi-country earners make better financial decisions without
requiring full manual bookkeeping.

In one sentence:

> NomadFi is a cross-border financial decision engine that helps users maximize
> rewards, avoid debt, reduce FX waste, protect credit health, and learn tax and
> investing strategy using verified, privacy-preserving financial context.

This roadmap is governed by [`docs/MISSION.md`](./MISSION.md) and the evidence
standards in [`docs/README.md`](./README.md). Features that do not advance the
decision-assistant mission should be delayed, demoted to optional tools, or
removed from primary navigation.

---

## Solidified Product Goals

1. **Choose the best card or payment method.** Recommend the best available
   card, debit rail, Wise balance, or local payment method for a specific
   purchase using currency, location, rewards, FX fees, utilization, statement
   timing, and source confidence.
2. **Protect and improve credit leverage.** Track credit limits, balance
   snapshots, available credit, statement close dates, due dates, and payment
   timing without ever recommending debt or interest.
3. **Reduce cross-border money leakage.** Surface avoidable costs from FX fees,
   dynamic currency conversion, issuer conversion spreads, and cross-border
   subscription pricing.
4. **Guide financial setup across jurisdictions.** Represent jurisdictions,
   cards, accounts, currencies, and life context as stable profile data plus
   optional live snapshots.
5. **Teach tax and investing concepts safely.** Provide source-backed education
   for region-specific tax and investing concepts while avoiding professional
   tax, legal, immigration, or investment advice.
6. **Use AI as the interface, not the source of truth.** Let AI parse user
   intent and explain tradeoffs, while deterministic, cited rules remain the
   recommendation authority.
7. **Keep manual tools secondary.** Ledger and Tax Vault remain available as
   optional support tools, but they should not define the primary experience
   until automatic import/sync or stronger decision-assistant use cases make
   them central.

---

## Roadmap Status Legend

- `[x]` **Shipped** — code is in the repo and covered by tests or user-visible UI.
- `[~]` **Partially shipped** — the capability exists for a subset of use cases
  (e.g. Scenario 1 only) or the scaffolding is in place but the user-facing
  surface is incomplete.
- `[ ]` **Planned** — on the roadmap, not implemented yet.
- `[!]` **Deferred** — intentionally not being built now; may be revisited only
  if a concrete product need appears.

Every `[x]` below is backed by a code path. Where relevant, the evidence note
points at the test file that pins the behaviour.

---

## Roadmap Progress

### Governance and safety foundation

- [x] Source governance document — [`docs/README.md`](./README.md).
- [x] Mission document — [`docs/MISSION.md`](./MISSION.md).
- [x] Private testbed isolation — `docs/ARIEL.md` exists and is kept out of
  this public file by policy.
- [x] Source provenance modelling — `SourceProvenance`, `SourceConfidence`
  in `Core/Models/`. _Evidence: `NomadFiTests/SourceProvenanceTests.swift`,
  `SourceProvenancePhase2Tests.swift`._
- [x] Complete on-device data wipe — `DataGovernancePolicy.deleteAllUserData`
  deletes every SwiftData model, Keychain entries, receipt images, Spotlight
  entries, and pending notifications.
- [x] Zero analytics / zero third-party SDKs.

### Navigation and surface

- [x] Decision Assistant is the primary tab — `MainTabView` bottom tabs are
  Dashboard / Decisions / Settings.
- [x] Ledger, Tax Vault, and Subscriptions live under Settings →
  Advanced Tools — `Features/Settings/Hub/AdvancedToolsSettingsView.swift`.
- [x] Editable jurisdictions after onboarding —
  `Features/Settings/Jurisdictions/JurisdictionManagementView.swift`.
  _Evidence: `JurisdictionManagerTests.swift`._

### Account and credit-card data model

- [x] Account profile vs. live snapshot separation — `Account` carries
  `creditLimit` (profile) distinct from `currentBalance` / `availableCredit` /
  `statementBalance` (snapshots). _Evidence:
  `AccountFinancialSnapshotTests.swift`._
- [x] Snapshot source provenance and freshness — `FinancialSnapshotSource`
  with per-source `freshnessWindow`; `Account.isFinancialSnapshotStale(now:)`.
- [x] Credit-card statement calendar — `CreditCardSchedule`,
  `CreditCardScheduleState`, `Features/Settings/CreditCardScheduleEditView.swift`.
  _Evidence: `CreditCardScheduleTests.swift`._
- [x] Credit-card reminders — `CreditCardReminderPlanner` +
  `NotificationManager+CreditCardReminders`. _Evidence:
  `CreditCardReminderPlannerTests.swift`._
- [x] Nil balances are never treated as zero — exclusion from net worth
  for credit cards without a saved balance.

### Deterministic decision engines

- [x] Scenario 1: Amazon arrival-order engine — `ScenarioDecisionEngine` +
  `ScenarioDecisionRecord`. _Evidence: `ScenarioDecisionEngineTests.swift`,
  `ScenarioDecisionRecordTests.swift`._
- [x] Credit Timing Decision v1 — `CreditTimingDecisionEngine` with CFPB +
  myFICO citations, six per-card rulings (`needsSetup`, `snapshotStale`,
  `scheduleMissing`, `readyNoUrgentAction`, `payDownBeforeClose`,
  `nearLimitAvoidMoreSpend`), near-limit / paydown guidance, stale-snapshot
  and unconfirmed-schedule gates. _Evidence:
  `CreditTimingDecisionEngineTests.swift`._
- [x] Generic Purchase Decision Engine v1 — `PurchaseDecisionEngine` with
  merchant / category / amount / currency / location context, per-account
  stances (`recommended`, `fallback`, `usableWithCaveats`, `insufficientFunds`,
  `insufficientCreditCoverage`, `snapshotStale`, `needsSetup`,
  `excludedInvestment`), FX-verification caveats, and CFPB + myFICO
  citations. Rewards are intentionally *not* used for ranking. _Evidence:
  `PurchaseDecisionEngineTests.swift`, `PurchaseDecisionRecordTests.swift`._
- [~] "Which card should I use?" — routed through Scenario 1 today. With
  the generic engine in place, the voice surface can be widened in the
  next phase via `RecommendCardIntent`.
- [x] Verified rewards / category-bonus model on `Account` —
  CloudKit-safe primitive fields (`rewardProgramName`,
  `rewardUnitRawValue`, `baseRewardRate`,
  `rewardCategoryOverridesRaw` (JSON), plus source provenance)
  projected through `RewardProfile` / `RewardRateEvaluation`. The
  engine uses rewards for ranking only when a verified source is on
  file, it's still inside the 30-day issuer-terms freshness window,
  and the reward units are comparable across candidates.
  Dedicated Settings editor at **Account → Rewards Terms** mirrors
  the credit-card calendar flow. _Evidence: `RewardProfileTests.swift`,
  `CreditCardRewardsEditViewModelTests.swift`, reward-aware cases in
  `PurchaseDecisionEngineTests.swift` and `RecommendCardIntentTests.swift`._
- [x] Cross-card payment-allocation planning —
  `CreditPaymentAllocationPlanner` projects per-card assessments
  into a currency-grouped plan with deterministic priority
  (near-limit → earliest statement close → higher utilization →
  stable alphabetical). Supports an optional, non-persisted
  `CreditPaymentAllocationBudget` that fills conservative 30 %
  targets in priority order before bleeding into the optional
  stronger 10 % target, never exceeding the strong per-line
  amount. Multi-currency portfolios stay grouped — NomadFi never
  sums USD + CAD as if an FX rate were known. _Evidence:
  `CreditPaymentAllocationPlannerTests.swift`._
- [x] Credit-limit-increase **readiness checklist** —
  `CreditLimitReadinessEvaluator` produces a per-card
  `readyToReview` / `needsMoreEvidence` summary, never an approval
  claim. Issuer-only facts (income, on-time payment history,
  account age, hard-inquiry policy, issuer eligibility) always
  surface as `.issuerOnly` caveats and are never flipped to met.
  _Evidence: `CreditLimitReadinessEvaluatorTests.swift`._
- [x] **Recent spending context inside Credit Timing** —
  `CreditTimingSpendingContextBuilder` projects the Phase 4
  `SpendingTrendSummary` into a calm read-only section with
  currency-aware latest-month totals, a prior-month or
  trailing-average baseline, a ±5 % `rising`/`falling`/`steady`
  direction, top-3 categories, and an other-currency caveat
  count. Wired through `CreditTimingDecisionEngine.decide(...,
  spendingTrend:)`; context never modifies paydown targets.
  _Evidence: `CreditTimingSpendingContextBuilderTests.swift`,
  `CreditTimingSpendingContextDecisionTests.swift`._

### Decision drafts (user-captured raw context)

- [x] Draft capture form — `DecisionDraftFormView` (create mode) + VM.
- [x] Draft detail sheet — `DecisionDraftDetailView`.
- [x] Draft lifecycle — edit mode, archive, restore, and individual
  `confirmationDialog`-guarded delete via `DecisionDraftStore`. _Evidence:
  `DecisionDraftLifecycleTests.swift`, `DecisionDraftRecordTests.swift`._
- [x] Draft archive / active section separation in the Decision Assistant.
- [x] Drafts are never auto-analyzed, never promoted to the catalog,
  never routed into `ScenarioDecisionEngine`.

### Voice / App Intents surface

- [x] App Intents modernised to iOS 18+ `supportedModes` (no deprecated
  `openAppWhenRun`). _Evidence: `DecisionAssistantIntentModeTests.swift`._
- [x] `OpenDecisionAssistantIntent`, `ReviewAmazonArrivalDecisionIntent`,
  `ContinueAmazonArrivalDecisionIntent`, `ActiveCardIntent` (rewired to
  the Scenario 1 engine, no FX-fee-only ranking).
- [x] `CaptureDecisionDraftIntent` — voice intake for decision drafts;
  status `needsEngine`, no analysis. _Evidence:
  `DecisionDraftIntentTests.swift`._
- [x] Honest dialog formatters — no "analyzed", "recommended", "best card",
  or "verified" language for unverified paths. _Evidence:
  `DecisionAssistantIntentDialogTests.swift`._
- [x] `ReviewCreditTimingIntent` — background voice review of the Credit
  Timing engine, no score predictions. _Evidence:
  `RecommendCardIntentTests.swift`._
- [x] `RecommendCardIntent` — background voice ranking on top of the
  generic `PurchaseDecisionEngine`, with AppEnum adapters
  (`MerchantCategoryAppEnum`, `CurrencyCodeAppEnum`) so the core
  domain enums stay free of `AppIntents`. No rewards ranking, no
  "best card" / "lowest fee" framing, voice queries never
  persisted. _Evidence: `RecommendCardIntentTests.swift`._

### Transaction capture / aggregation

- [~] Manual transaction entry — `Features/Ledger/AddTransactionView.swift`
  exists; demoted to Settings → Advanced Tools until a decision surface
  needs it.
- [~] Receipt scanning — `ReceiptScannerService`, `ReceiptCategorizer`,
  `TaxVault` flows exist; still kept in Advanced Tools.
- [x] CSV import for bank/card exports — deterministic two-phase
  (parse → commit) pipeline in `Core/Services/Import/`
  (`CSVRowParser`, `CSVImportProfile`, `TransactionImportProfile`,
  `TransactionImportService`) with header-driven profile detection for
  Chase-like, CIBC-like, Amex-Canada-like, Wise-like, and generic
  shapes. Preview UI at Settings → Advanced Tools →
  **Transaction Import**. Fully on-device; no file leaves the
  sandbox. _Evidence: `CSVRowParserTests.swift`,
  `CSVImportProfileDetectionTests.swift`,
  `TransactionImportServiceTests.swift`._
- [x] Merchant normalisation — `MerchantNormalizer` strips processor
  prefixes (`SQ *`, `TST*`, `PAYPAL *`, `AMZN*`, etc.), trailing store
  numbers, short-date suffixes, and CITY-ST-ZIP blocks. Persisted on
  `Transaction.normalizedMerchantName` for clustering. _Evidence:
  `MerchantNormalizerTests.swift`._
- [x] Transaction deduplication across sources — `TransactionImportDeduper`
  matches on external transaction ID (strongest) or a four-part
  `merchant|amount|date|currency` fingerprint within a configurable
  day window. Legacy rows without the new schema fields still match
  via fingerprint synthesis. _Evidence:
  `TransactionImportDeduperTests.swift`._
- [ ] Merchant categorisation ML (tiny deterministic keyword map
  ships in `MerchantCategoryInferrer`; ML pass still `[ ]`).
- [x] Recurring-charge detection across the portfolio —
  `RecurringChargeDetector` runs on any `[Transaction]` and is
  consumed by the existing Subscriptions surface
  (`SubscriptionDetector` now delegates). Weekly / monthly /
  quarterly / annual cadences with ±5 % amount tolerance; income
  and transfer categories are excluded. _Evidence:
  `RecurringChargeDetectorTests.swift`._
- [x] Spend anomaly detection — deterministic, on-device,
  two-kind detector (`SpendAnomalyDetector`) layered on top of
  the recurring engine. Surfaces `.missingRecurringCharge` when
  an expected recurring charge passes its grace window without
  a matching transaction and `.amountSpike` when the latest
  broad-merchant match is ≥25 % above the bucket baseline and
  ≥ $5 absolute delta. Cross-currency rows stay separate; one-off
  merchants, transfers, and income never produce anomalies.
  Surfaced through the existing `InsightEngine` as
  `.anomaly`-category `FinancialInsight` cards on the Dashboard
  — no new screen, no drilldown. _Evidence:
  `SpendAnomalyDetectorTests.swift`,
  `InsightEngineSpendAnomalyTests.swift`._
- [x] Spending-trend Dashboard card — read-only category × month
  grid (`SpendingTrendComputer` + `SpendingTrendCard`). Hides when
  activity is below the floor (3 qualifying transactions in a
  dominant currency inside the 3-month window). Excludes income
  and transfer categories; normalises sign conventions by
  magnitude. _Evidence: `SpendingTrendComputerTests.swift`._

### Tax and investing education

- [~] Tax Vault — now split into three peer surfaces
  (**Review / Learn / Archive**) under one segmented switcher.
  Review owns the in-content scan CTA and the tax-category
  suggestion queue; Learn owns the jurisdiction-aware education
  starter (Phase 7A), persisted progression (Phase 7B),
  knowledge-check quizzes (Phase 7C), and calm recognition
  badges (Phase 7D); Archive owns the searchable year /
  jurisdiction document list with per-year exports. Remaining
  work: deeper investment-account lessons and receipt /
  document organisation prompts.
- [~] Region-specific tax education (Phase 7A + 7B + 7C + 7D) —
  locally-authored, source-backed starter covering United States
  (3 lessons + 1 checklist + 1 quiz), Canada
  (3 lessons + 1 checklist + 1 quiz), and Trinidad and Tobago
  (2 lessons + 1 checklist + 1 quiz). Every lesson — and every
  quiz question — cites only official sources already enumerated
  in `docs/README.md` (IRS / CRA / BIR / Ministry of Finance /
  FIUTT). Surfaced inside the Tax Vault **Learn** peer surface,
  driven by `JurisdictionProfile` with home-first ordering. Phase
  7B added explicit **Mark reviewed** and checklist-toggle
  actions plus a **Next to review** pointer; Phase 7C added a
  **Knowledge check** row that unlocks after the checklist and
  lessons are reviewed and persists attempt scores via the same
  CloudKit-safe `TaxEducationProgressRecord` `@Model`; Phase 7D
  adds calm current-state **recognition badges** derived purely
  from that same record — no new persistence. _Evidence:
  `TaxEducationCatalogTests.swift`,
  `TaxEducationSelectorTests.swift`,
  `TaxEducationProgressServiceTests.swift`,
  `TaxEducationQuizCatalogTests.swift`,
  `TaxEducationQuizScoringTests.swift`,
  `TaxEducationQuizServiceTests.swift`,
  `TaxEducationRecognitionComputerTests.swift`,
  `TaxVaultSurfaceTests.swift`._
- [ ] Deeper investment-account lessons (IRA for the U.S.,
  TFSA / RRSP deep dives beyond the current high-level starter).
- [ ] Receipt / document organisation prompts tied to the
  education checklists.
- [ ] Investing education + index-fund tracking.

### Apple capability tracks

- [~] **FinanceKit evaluation + provider architecture (Phase 5A + 5B).**
  Phase 5A shipped the provider-neutral architecture under
  `Core/Services/FinancialData/`: `FinancialDataProvider`,
  `FinancialDataProviderKind` (manual / csvImport / financeKit /
  externalAggregator), typed availability / authorization / connection
  surfaces, provider-neutral `FinancialAccountSnapshot` +
  `FinancialTransactionSnapshot`, and a `FinancialDataSyncCoordinator`
  that fans out across every registered provider with graceful
  degradation. FinanceKit lives in `FinanceKitFinancialDataProvider`
  with real availability / authorization calls and a typed mapping
  seam; the external-aggregator placeholder pins the boundary for a
  later Plaid-vs-Akoya bakeoff without shipping any vendor SDK.
  Phase 5B wired the architecture into product plumbing:
  `FinancialDataReconciler` under
  `Core/Services/FinancialData/Reconciliation/` merges a
  `FinancialDataSyncReport` into the SwiftData store with pinned
  rules (durable provider identity wins → narrow fallback → never
  cross-merge → reuse `TransactionImportDeduper`); `Account` grew
  CloudKit-safe provider-link fields (`providerLinkKindRawValue`,
  `providerExternalAccountID`, `providerConnectionID`,
  `providerInstitutionIdentifier`, `providerLastSyncedAt`);
  `Transaction` grew a provider-neutral `providerKindRawValue`; and
  Settings → Financial Setup → **Financial Connections** renders
  per-provider availability / authorization / connection state with
  an explicit **Sync Now** action. `NSFinancialDataUsageDescription`
  added to the app target so the FinanceKit consent prompt has the
  required purpose string. _Evidence:
  `FinancialDataProviderArchitectureTests.swift`,
  `FinancialDataReconcilerTests.swift`,
  `FinancialConnectionsViewModelTests.swift`._
  Remaining for later: real device / managed-entitlement rollout and
  a concrete third-party aggregator bakeoff.
- [!] Apple Pay integration — deferred until NomadFi sells something.
- [!] Wallet card scraping / unrestricted Wallet access — deferred; Apple
  does not expose this.
- [ ] Apple Intelligence on-device context (optional input to the
  scenario engine when entitlements and user consent are in place).
- [!] Generic-AI financial recommendations — deferred indefinitely by
  product decision; violates the deterministic source-backed rule.
- [!] Credit-score prediction — deferred; scoring models are proprietary.
- [!] Personalized investment advice — deferred; regulatory risk.
- [!] Guaranteed credit-limit-increase promises — deferred; issuer models
  are proprietary.

---

## Product Direction

NomadFi should be designed around decisions, not around manual transaction
entry. Apple Pay, Apple Wallet, and FinanceKit are evaluated only by whether
they advance the mission above.

NomadFi should not start by integrating Apple Pay or Apple Wallet.

Apple Pay is primarily for accepting payments inside an app. Apple Wallet and
PassKit can help an app create or manage its own passes, check broad payment
capability, or support issuer provisioning if the app is a bank or card issuer.
They do not provide a free universal feed of every card a user has in Wallet,
nor do they give arbitrary apps full transaction history for Chase, CIBC,
American Express Canada, Wise, Trinidad and Tobago accounts, or other issuers.

The most reliable near-term route is:

1. Build NomadFi's card decision engine from user-consented, on-device data.
2. Add Siri / App Intents so users can ask which card to use in context.
3. Use deterministic, source-cited rules for financial recommendations.
4. Use AI and ML to interpret messy human intent and classify transactions,
   not to invent financial facts.
5. Evaluate FinanceKit later as an enhancement, not as the product foundation.

---

## Apple Capability Decision Matrix

| Capability | What It Can Do | What It Cannot Do | Cost / Access | NomadFi Need |
|---|---|---|---|---|
| Apple Pay through PassKit | Let NomadFi accept Apple Pay payments for goods, services, or donations inside the app | Cannot read a user's Wallet card list, balances, limits, rewards, statements, or full transaction history | Free APIs, but requires merchant setup and payment processing if selling something | Not needed now |
| Apple Pay capability checks | Check whether the device can make Apple Pay payments and whether any card supports broad networks such as Visa, Mastercard, Amex, or Discover | Does not identify exact cards or decide which of a user's cards is optimal | Free | Low value for NomadFi recommendations |
| Apple Wallet passes | Let NomadFi create its own pass, membership card, coupon, or stored credential | Cannot inspect arbitrary bank cards or transaction history in Wallet | Free APIs, but pass signing and operational setup are required | Optional later, not central |
| Wallet issuer provisioning | Let an issuer add its payment card to Apple Wallet from its app or Wallet extensions | NomadFi cannot use this unless it becomes an issuer or has issuer partnerships | Requires issuer/partner capability and entitlements | Not relevant now |
| FinanceKit | With Apple approval and user consent, access supported on-device financial accounts, transactions, balances, and related data | Not universal coverage; requires a managed entitlement; availability varies by region and supported institution | Free API, but entitlement-gated and reviewed by Apple | Best Apple-native future option, not a foundation |
| App Intents / Siri | Let users ask NomadFi contextual questions such as "Which card should I use at Target?" | Does not automatically know Wallet cards unless NomadFi already has data | Free and directly aligned with the product | High priority |
| CoreLocation | Infer whether a user is at home, abroad, or near a merchant category when permission is granted | Does not provide payment-card data | Free with user permission | High priority for contextual recommendations |

---

## Core Tradeoffs

### Apple Pay Is Not the Card-Intelligence Layer

Apple Pay would help only if NomadFi needs to receive payments, for example a
future subscription checkout. It does not solve the current product problem:
knowing which card a user should use, why, and when.

**Decision:** Do not integrate Apple Pay until NomadFi sells something in-app or
on the web.

### Apple Wallet Is Not a Universal Data Source

Wallet is privacy-constrained. Apps can manage passes they create or are
entitled to access, but they cannot freely enumerate every arbitrary payment
card and transaction in a user's Wallet.

**Decision:** Do not build a product plan that depends on unrestricted Wallet
card or transaction access.

### FinanceKit Is Promising but Entitlement-Gated

FinanceKit is the legitimate Apple-native path for financial data, but it
requires a managed entitlement, Apple review, and current coverage is not
universal. It should be integrated through an adapter layer so NomadFi still
works without it.

**Decision:** Design for FinanceKit later, but keep the core product functional
with manual, imported, and user-verified data.

### AI Should Explain and Structure, Not Guess

Financial recommendations must come from verified product terms, user-provided
facts, and deterministic rules. AI can parse natural language, classify
transactions, summarize tradeoffs, and teach concepts, but it must not invent
tax, credit, rewards, or investment advice.

**Decision:** AI is the interface and reasoning assistant; source-cited rules
remain the decision authority.

---

## Phase 0 — Governance and Scope Lock

**Status:** `[x]` Shipped.

**Goal:** Keep the roadmap technically honest before adding integrations.

### Build

- Maintain the source hierarchy in `docs/README.md`.
- Keep private testbed facts in `docs/ARIEL.md`, not public docs.
- Treat Apple Pay, Wallet, and FinanceKit as separate capabilities, not one
  vague "Wallet integration."
- Document every recommendation as one of:
  - user-provided
  - verified primary source
  - verified secondary source
  - institutional / peer-reviewed
  - indicative
  - inference

### Do Not Build

- Do not add Apple Pay just to say NomadFi supports Apple Pay.
- Do not imply NomadFi can automatically read every Wallet card.
- Do not hard-code unverified issuer rewards, fees, tax rules, or score impact.

### Tradeoff

This slows down flashy integrations, but prevents the app from building on
capabilities Apple does not expose and protects user trust.

---

## Phase 1 — On-Device Financial Testbed and Manual Truth

**Status:** `[x]` Core surface shipped. The testbed is complete for Scenario 1
and Credit Timing v1; automatic aggregation (Phase 4 / Phase 5) is still out.

**Goal:** Make NomadFi useful without external account aggregation.

### Sub-phase ledger

- `[x]` **Decision Assistant as the core surface.** Decisions tab hosts Active
  Decision, Previous Decisions, captured drafts, archived drafts, and a
  "Gather intelligence" intake card. Ledger / Tax Vault / Subscriptions are
  demoted to Settings → Advanced Tools.
- `[x]` **Account Profiles + Live Snapshots.** `Account` separates profile
  facts (type, currency, jurisdiction, credit limit) from live snapshots
  (current balance, available credit, statement balance), each timestamped
  with a `FinancialSnapshotSource`. Credit limits are capacity, never counted
  as net worth; credit cards without a balance snapshot are excluded and
  labelled, never treated as zero debt.
- `[x]` **Credit-card statement calendar.** Users enter period start, closing,
  due, and confirmation state; schedule state drives reminder eligibility and
  engine guardrails.
- `[x]` **Credit-card reminders.** Statement-close (two-day lead) and
  payment-due (three-day lead) reminders fire only off a confirmed schedule.
- `[x]` **Scenario 1 — Amazon arrival order.** Deterministic `ScenarioDecisionEngine`
  with Amazon / Chase / Wise source citations and a per-scenario record.
- `[x]` **Credit Timing Decision v1.** Portfolio-wide readiness engine —
  per-card rulings, paydown-to-30% / paydown-to-10% planning, near-limit
  guidance, stale-snapshot and unconfirmed-schedule gates, CFPB and myFICO
  citations, and three pinned hard rules. No score prediction, no
  carry-a-balance guidance.
- `[x]` **Decision Draft intake v1.** `DecisionDraftRecord` stores user-written
  scenarios on-device with status `needsEngine`; drafts render in a dedicated
  "Gathered intelligence" section, visually distinct from analyzed decisions.
- `[x]` **Decision Draft lifecycle v1.** Create + edit, archive, restore, and
  per-draft destructive delete with `confirmationDialog`. Archived drafts get
  their own quieter section.
- `[x]` **Siri / App Shortcut draft intake v1.** `CaptureDecisionDraftIntent`
  captures a dictated scenario as a draft on-device, `.background` mode,
  never analyzed. Dialog copy explicitly marks the result as needing an
  engine.

### Why this comes first

This data is already enough to answer high-value questions:

- Should I use Chase, Wise, or a Canadian card for this purchase?
- Will this purchase create high reported utilization?
- When should I pay to reduce the balance likely reported at statement close?
- Which card has verified or unverified FX assumptions?

### Tradeoff

Manual data entry is less seamless than automatic aggregation, but it is
reliable, free, entitlement-free, and works across Canada, the United States,
Trinidad and Tobago, Wise, and other cross-border accounts.

---

## Phase 2 — Siri and App Intent Card Recommendation

**Status:** `[~]` Partially shipped. The App Shortcuts surface is modernised
and wired to Decision Assistant / Scenario 1 / draft capture. A merchant- and
category-agnostic `RecommendCardIntent` is **not** yet shipped and is
dependent on Phase 3.

**Goal:** Let the user ask for a card recommendation in natural language.

### Shipped this phase

- `[x]` Modernised App Intents using `supportedModes` (no deprecated
  `openAppWhenRun`).
- `[x]` `OpenDecisionAssistantIntent` (foreground, routes to the Decisions
  tab via a persisted `MainTabSelection`).
- `[x]` `ReviewAmazonArrivalDecisionIntent` (background, runs the
  Scenario 1 engine and speaks the current ruling).
- `[x]` `ContinueAmazonArrivalDecisionIntent` (foreground, opens the app
  and speaks a short scene-setter).
- `[x]` `ActiveCardIntent` — legacy "Which card?" phrase kept for
  discoverability, now explicitly honest about NomadFi's scenario
  coverage rather than giving a generic FX-fee ranking.
- `[x]` `CaptureDecisionDraftIntent` — voice draft intake.
- `[x]` App Shortcuts metadata extraction confirmed in every build.

### Still to build

- `[ ]` `ReviewCreditTimingIntent` — voice-only background review of the
  Credit Timing engine.
- `[ ]` `RecommendCardIntent` with merchant, category, amount, currency,
  and location-context parameters. Blocked on Phase 3's generic engine.

### Example user request

"I am in San Francisco at Target, buying groceries for this week's meal prep,
and I need to know which card I should use and how I should approach this."

### Tradeoff

Siri gives the product a strong interaction model before automatic financial
data aggregation exists. The limitation is that the answer is only as good as
the data NomadFi already has.

---

## Phase 3 — Context-Aware Card Decision Engine

**Status:** `[~]` Partially shipped. Generic Purchase Decision Engine v1
(see [`PurchaseDecisionEngine`](../NomadFi/NomadFi/Features/DecisionAssistant/PurchaseDecision/PurchaseDecisionEngine.swift)
and tests `PurchaseDecisionEngineTests.swift` / `PurchaseDecisionRecordTests.swift`)
now ranks the user's saved accounts for a typed merchant / category /
amount / currency / location purchase. Rewards ranking is intentionally
out of scope until verified issuer rewards data exists; the engine only
emits a consolidated "verify rewards" checklist entry for
rewards-sensitive categories. A merchant-aware Siri
`RecommendCardIntent` is still `[ ]`.

**Goal:** Make the recommendation engine robust enough to operate across real
life contexts.

### Build

- A merchant/category model for groceries, dining, transit, online shopping,
  school, health, subscriptions, and travel.
- A travel-mode detector based on user-confirmed location context.
- A deterministic ranking engine that weighs:
  - no debt / no interest as a hard constraint
  - statement close timing
  - current utilization
  - available credit
  - foreign transaction fees
  - rewards value
  - issuer acceptance risk
  - refund / dispute considerations
  - cash-flow timing
- A recommendation format that always includes:
  - best option
  - why
  - when not to use it
  - fallback
  - source confidence

### Hard Rules

- Never recommend carrying credit-card debt for rewards.
- Never recommend a cash advance.
- Never guarantee a credit-limit increase.
- Never present score effects as deterministic.
- Never rank rewards above avoiding interest, fees, or missed payments.

### Tradeoff

A deterministic engine is less flashy than a pure AI chat answer, but it is
auditable, testable, and safer for financial decisions.

---

## Phase 4 — Transaction Capture Without Wallet Dependency

**Status:** `[~]` Partially shipped. Manual entry, receipt scanning, CSV
import, merchant normalisation, and deterministic dedupe are all live.
Recurring-charge generalisation, spending-trend surface, and
categorisation ML are still out.

**Goal:** Improve spending intelligence before FinanceKit is available.

### Already shipped

- `[x]` Manual transaction entry (`Features/Ledger/AddTransactionView.swift`).
- `[x]` Receipt scanning and confirmation (`ReceiptScannerService`,
  `ReceiptCategorizer`, Tax Vault flows).
- `[x]` Subscription detection (`SubscriptionDetector`, separate flow
  scoped to subscriptions).
- `[x]` CSV import pipeline (`Core/Services/Import/`): pure
  `CSVRowParser` (RFC 4180 style, CRLF/LF/BOM safe), header-driven
  profile detection (`TransactionImportProfile` catalog for
  Chase-like, CIBC-like, Amex-Canada-like, Wise-like, generic), a
  two-phase `TransactionImportService.parse(...) → commit(...)` so
  the user reviews counts before anything is written, and a
  dedicated `TransactionImportView` reached from Settings →
  Advanced Tools → **Transaction Import**.
- `[x]` Merchant normalisation (`MerchantNormalizer`) — deterministic
  processor-prefix / store-number / short-date / city-state-zip
  stripping. Normalised form persisted on
  `Transaction.normalizedMerchantName`, separate from the original
  `merchantName` the UI shows.
- `[x]` Deterministic dedupe (`TransactionImportDeduper`) —
  external-transaction-ID match (strongest) or a `merchant|amount|
  date|currency` fingerprint match within a configurable day window.
  New Transaction fields (`externalTransactionID`, `importSource`,
  `importedAt`, `importFingerprint`, `normalizedMerchantName`) are
  all optional / defaulted so the schema stays CloudKit-safe.

### Shipped this slice

- `[x]` Generalised recurring-charge detector
  (`Core/Services/RecurringChargeDetector.swift`) — pure value type
  output (`RecurringChargeCandidate`) so engines and UIs can
  consume it without a main-actor hop on the candidate itself.
  Reuses `MerchantNormalizer` for clustering, so CSV-imported and
  manually-entered rows collapse together. `SubscriptionDetector`
  is now a thin adapter that projects candidates onto
  `DetectedSubscription`, preserving every call-site in the
  Subscriptions surface. Cadences: weekly, monthly, quarterly,
  annual, each with a pinned tolerance. Income and transfer
  categories are filtered before grouping.
- `[x]` Read-only Dashboard spending-trend card
  (`Core/Services/SpendingTrendSummary.swift`,
  `Core/Services/SpendingTrendComputer.swift`,
  `Features/Dashboard/Components/SpendingTrendCard.swift`). Bins by
  calendar month × category for the last three months; rows sort
  desc by total spend. Hides automatically when activity is below
  the display floor or when every category row is zero after
  filtering. Currency-dominant rows feed the grid; other-currency
  rows are counted and surfaced as a caveat. Absolute month
  labels ("April 2026"), never relative ones.

### Still to build

- `[x]` Tax-category suggestions with confidence labels —
  deterministic `TaxCategorySuggestionEngine` proposes a
  `TaxCategory` per eligible transaction with `high` /
  `medium` / `low` confidence and a short reason list. Review
  queue lives under **Tax Vault → Suggestions to review**; a
  modal review sheet lets the user confirm (creates a linked
  `TaxDocument`) or dismiss (never resurfaces). Three
  CloudKit-safe fields added to `Transaction`
  (`taxSuggestionStatusRawValue`, `taxSuggestionLastReviewedAt`,
  `taxSuggestionCategoryRawValue`) — all optional / defaulted.
  NomadFi never flips `isTaxDeductible` automatically. _Evidence:
  `TaxCategorySuggestionEngineTests.swift`,
  `TaxSuggestionReviewViewModelTests.swift`._
- `[x]` Spend anomaly detection — two-kind deterministic
  detector under `Core/Services/`
  (`SpendAnomalyKind` / `SpendAnomaly` / `SpendAnomalyDetector`).
  Layered on top of `RecurringChargeDetector`; requires a
  history of ≥3 matching charges before surfacing anything.
  `.missingRecurringCharge` fires when the expected next charge
  passes its per-cadence grace window (weekly 3d, monthly 7d,
  quarterly 14d, annual 30d) and is inside the max-overdue
  window (weekly 14d, monthly 45d, quarterly 120d, annual 400d).
  `.amountSpike` fires when the latest broad merchant+currency
  match is ≥25 % above the bucket baseline AND ≥ $5 absolute
  delta — well beyond the recurring detector's ±5 % jitter
  tolerance. Cross-currency rows never merge. Surfaced as
  `.anomaly`-category `FinancialInsight` cards on the existing
  Dashboard insight row, no new screen. _Evidence:
  `SpendAnomalyDetectorTests.swift`,
  `InsightEngineSpendAnomalyTests.swift`._
- `[ ]` On-device merchant-category ML (a tiny deterministic keyword
  map ships today in `MerchantCategoryInferrer`).

### Optional later

- Email receipt import, only if privacy and permissions can be handled well.
- Bank export parsing by institution.
- On-device merchant-category ML.

### Tradeoff

CSV/manual capture is less automatic than live bank feeds, but it avoids paid
aggregators, broad credential access, and unavailable Wallet data.

---

## Phase 5 — Provider-Neutral Financial Data Architecture

**Status:** `[~]` Architecture + reconciliation shipped. Phase 5A
landed the provider-neutral abstraction under
`Core/Services/FinancialData/`; Phase 5B connected it to product
plumbing via the reconciler and the Settings page. FinanceKit's
managed entitlement and any concrete third-party aggregator bakeoff
remain as follow-ups.

**Goal:** Give NomadFi a provider-neutral financial-data layer so
manual / CSV / FinanceKit / (later) external aggregators all feed the
same `Account` + `Transaction` store without hard-wiring the product
to any one upstream.

### Shipped (5A)

- `FinancialDataProvider` protocol with a typed
  `FinancialDataProviderKind` identity (`manual`, `csvImport`,
  `financeKit`, `externalAggregator(identifier:)`).
- Typed surfaces: `FinancialDataProviderAvailability`,
  `FinancialDataAuthorizationStatus`,
  `FinancialDataConnection` (+ `Status`), `FinancialDataProviderError`.
- Provider-neutral snapshot contract:
  `FinancialAccountSnapshot`, `FinancialTransactionSnapshot`. Both
  reuse existing domain enums (`AccountType`, `CurrencyCode`,
  `TransactionCategory`) and project onto the existing
  `FinancialSnapshotSource` so engines keep consuming the same
  provenance signal they do today.
- Adapters:
  - `ManualFinancialDataProvider` (always available / authorized —
    represents the user-typed SwiftData truth).
  - `CSVImportFinancialDataProvider` (CSV import seam).
  - `FinanceKitFinancialDataProvider` (real availability /
    authorization / typed mapping; snapshot fetches stay no-op until
    Apple provisions the managed entitlement; background-update hook
    declared as a seam).
  - `ExternalAggregatorFinancialDataProvider` (placeholder that
    reports `integrationNotImplemented` so the coordinator's
    fallback logic is testable end-to-end, and a real adapter can
    land later without restructuring the product).
- `FinancialDataSyncCoordinator` fans out every provider, reports
  `ProviderStatus` / `FinancialDataSyncReport` with deterministic
  per-provider outcomes, and degrades gracefully.
- `ServiceContainer` injects `financialDataCoordinator`
  (`.live()` / `.preview()`); the old
  `FinanceDataService` / `Live` / `Mock` files were removed.

### Shipped (5B)

- `FinancialDataReconciler` under
  `Core/Services/FinancialData/Reconciliation/` merges a
  `FinancialDataSyncReport` into SwiftData with four pinned
  invariants:
  1. Durable provider identity (provider-kind + external account ID)
     always wins the match.
  2. Fallback matching is narrow — institution + currency + account
     type, and only when exactly one existing account lines up.
  3. Ambiguous snapshots are counted as `unresolvedAmbiguousSnapshots`
     and never silently cross-merged.
  4. Transactions reuse `TransactionImportDeduper` (external ID →
     fingerprint within a day window). Dedupe is scoped to the
     linked account so rows never cross-attach.
- `FinancialDataReconciliationResult` summarises every pass
  (matched / created / updated accounts, inserted / duplicate /
  unresolved transactions) so the Settings page can render an
  honest after-sync chip.
- CloudKit-safe schema growth:
  - `Account` gained `providerLinkKindRawValue`,
    `providerExternalAccountID`, `providerConnectionID`,
    `providerInstitutionIdentifier`, `providerLastSyncedAt`, plus
    a derived `hasProviderLink` helper. `isFinanceKitLinked` is
    kept as a legacy compatibility bool; the new kind + external
    ID pair is authoritative.
  - `Transaction` gained a provider-neutral `providerKindRawValue`
    (persisted as a `FinancialDataProviderKind.logKey`). CSV rows
    continue to use `importSource`; manual rows stay blank. Every
    new field is optional / defaulted.
- Settings surface: **Settings → Financial Setup → Financial
  Connections** (`Features/Settings/Connections/`). Apple-Settings-style
  list with per-provider rows (availability, authorization state,
  connected / not enabled / authorization-required), an explicit
  **Sync Now** action, and the last reconciliation summary. Copy is
  calm and factual — pinned against a forbidden-phrase list.
- `NSFinancialDataUsageDescription` added to the app target
  (Debug + Release) so the FinanceKit consent prompt carries the
  required purpose string.

### FinanceKit feasibility notes (factual, not marketing)

- Data stays on-device; Apple never sees it.
- US coverage: Apple Card, Apple Cash, Apple Savings.
- UK coverage: selected open-banking institutions.
- Entitlement: `com.apple.developer.finance-kit`, managed by Apple.
- Availability varies by region, OS, and device — the app must stay
  useful when `.unavailable` is returned.

### Still to build

- Apple-provisioned `com.apple.developer.finance-kit` entitlement
  and real-device verification of the FinanceKit adapter's account
  and transaction fetch paths.
- Background update registration once Apple exposes the delivery
  entitlement. The seam is already declared on
  `FinanceKitFinancialDataProvider.scheduleBackgroundUpdates()`.
- Concrete third-party aggregator bakeoff (Plaid / MX / Akoya /
  Finicity or a direct FDX/FAPI integration). Must land behind the
  existing `ExternalAggregatorFinancialDataProvider` seam so the
  core domain model never imports a vendor SDK.

### Use provider data for

- Supported account discovery.
- Supported balances.
- Supported transactions.
- Background delivery where available and approved.

### Do not use provider data for

- Unsupported institutions.
- Tax advice by itself.
- Investment recommendations by itself.
- Credit-score predictions.
- Any path that breaks if entitlement is denied.

### Tradeoff

FinanceKit and a future permissioned aggregator make NomadFi feel
more automatic, but depending on any single upstream creates
entitlement, coverage, and review risk. The provider-neutral
architecture is the mitigation: manual and CSV stay as first-class
fallbacks so the core decision-assistant experience works even when
every upstream is unavailable.

---

## Phase 6 — Credit Leverage and Payment Timing

**Status:** `[x]` Shipped. Statement-close reminders, payment-due reminders,
utilization banding, near-limit guidance, per-card paydown targets,
**cross-card payment-allocation planning**, **credit-limit-increase readiness
checklist**, and **recent spending context inside Credit Timing** are all
live (Credit Timing v1 + Phase 6A + Phase 6B).

**Goal:** Help users build credit without debt.

### Already shipped

- `[x]` Statement-close reminders and payment-due reminders with
  confirmed-schedule gating (`CreditCardReminderPlanner`).
- `[x]` Current and projected utilization bands (Credit Timing engine).
- `[x]` Available-credit guardrails in Scenario 1 (Chase Freedom Rise
  path requires user-confirmed available credit plus buffer).
- `[x]` Near-limit warnings (Credit Timing `nearLimitAvoidMoreSpend` ruling).
- `[x]` "Pay before close" planning with issuer-reporting caveats and
  absolute-date copy.
- `[x]` **Cross-card payment-allocation planner** (Phase 6A) — pure
  value-layer planner under
  `Features/DecisionAssistant/CreditTiming/PaymentAllocation/`.
  Inputs are the engine's per-card assessments; outputs are a
  currency-grouped `CreditPaymentAllocationPlan` with deterministic
  priority, per-line conservative (30 %) and optional strong (10 %)
  paydown targets, blockers for cards that can't participate, and
  an optional non-persisted budget that's distributed across the
  matching currency only. Surfaced on the Credit Timing brief as a
  calm **Payment plan** section. _Evidence:
  `CreditPaymentAllocationPlannerTests.swift` (11 tests:
  eligibility, stale/unconfirmed blockers, priority ordering by
  severity → close date → utilization → alphabetical,
  paydown totals, multi-currency grouping, budget distribution
  across passes, copy guard for the banned vocabulary)._
- `[x]` **Credit-limit-increase readiness checklist** (Phase 6A) —
  `CreditLimitReadinessEvaluator` under
  `Features/DecisionAssistant/CreditTiming/CreditLimitReadiness/`.
  Six NomadFi-visible checks (credit limit on file, balance
  snapshot on file, snapshot freshness, statement calendar
  confirmed, utilization inside a conservative planning band, no
  near-limit signal) plus five permanent issuer-only caveats
  (income, on-time payment history, account age, hard-inquiry
  policy, issuer eligibility). Summary rolls up to **Ready to
  review** / **Needs more evidence** — never "you should request"
  or "you'll be approved". Surfaced on the brief as a **Limit
  readiness** section. _Evidence:
  `CreditLimitReadinessEvaluatorTests.swift` (8 tests: ready path,
  high/near-limit/stale/unconfirmed/missing-limit not-ready paths,
  issuer-only invariant across best- and worst-case inputs, sort
  order, copy guard)._
- `[x]` CFPB Regulation Z § 1026.53 payment-allocation citation
  added to `CreditTimingCitationCatalog` so the brief's Sources
  section can back the "NomadFi can't see your issuer's specific
  APR buckets" caveat.
- `[x]` **Recent spending context inside Credit Timing** (Phase 6B) —
  pure value-layer builder under
  `Features/DecisionAssistant/CreditTiming/SpendingContext/`.
  Takes the Phase 4 `SpendingTrendSummary`, projects it onto a
  calm `CreditTimingSpendingContext` (currency, latest month +
  total, prior-month or trailing-average baseline, direction
  ∈ { rising / falling / steady / insufficient } at a ±5 %
  threshold, signed percent change, top-3 categories,
  other-currency caveat count). Wired through
  `CreditTimingDecisionEngine.decide(..., spendingTrend:)` as an
  optional parameter — every existing caller keeps compiling with
  `nil`. Surfaced on the brief as a read-only **Recent spending
  context** section that hides itself when the trend is too thin.
  **Context only — never modifies paydown targets.** _Evidence:
  `CreditTimingSpendingContextBuilderTests.swift` (14 tests:
  nil/empty handling, one-month insufficient, two-month prior
  baseline, three-month trailing average, ±5 % thresholds incl.
  exact boundary, zero baseline handling, category cap, caveat
  pass-through, copy guard); `CreditTimingSpendingContextDecisionTests.swift`
  (3 tests: no-trend preserves legacy output byte-for-byte, trend
  attaches context without changing allocation totals or
  assessment paydown targets, no-credit-card path still exposes
  context)._

### Still to build

None for this milestone — Phase 6 is complete.

### Tradeoff

NomadFi can help users behave in ways generally associated with stronger credit
profiles, but it must not promise a score increase or a credit-limit increase.
Credit scoring and issuer risk models are proprietary.

---

## Phase 7 — Tax Efficiency Education

**Status:** `[~]` Partially shipped. Phase 7 entry (tax-category suggestion
bridge), Phase 7A (education starter with source-backed lessons and
region-aware checklists), Phase 7B (persisted user progress with
explicit "Mark reviewed" / checklist-toggle actions and a "Next to review"
pointer), Phase 7C (region-aware knowledge-check quizzes with explicit
submit + retake, deterministic scoring, and quiz-aware next-step /
progress-summary logic), and Phase 7D (calm current-state recognition
badges + Tax Vault IA split into Review / Learn / Archive peer surfaces)
are all live. Deeper investment-account lessons and receipt / document
organisation prompts are the outstanding continuations.

**Goal:** Teach region-specific tax concepts without crossing into professional
tax advice.

### Already shipped

- `[x]` Tax-category suggestion engine
  (`Core/Services/TaxSuggestions/TaxCategorySuggestionEngine.swift`) — pure,
  deterministic, keyword-driven. Maps transaction category + merchant /
  normalized-merchant / notes text to `TaxCategory` with three confidence
  buckets (`high` = text + category agreement, `medium` = category only,
  `low` = weak text-only signals for income / treaty / capital-gains). Excludes
  transfers, zero-amount rows, rows already linked to a `TaxDocument`, and rows
  whose `taxSuggestionStatus` is `dismissed` or `confirmed`.
- `[x]` Review queue surface — **Tax Vault → Suggestions to review** section
  renders pending suggestions with a confidence badge and a one-line reason
  summary. A dedicated review sheet (`TaxSuggestionReviewView`) lets the user
  edit the proposed category, confirm (creates a linked `TaxDocument` and
  marks status `confirmed`), or dismiss (marks status `dismissed`, never
  resurfaces).
- `[x]` CloudKit-safe persistence — three optional / defaulted fields on
  `Transaction` (`taxSuggestionStatusRawValue`,
  `taxSuggestionLastReviewedAt`, `taxSuggestionCategoryRawValue`). No
  `@Attribute(.unique)`, no new relationships, no silent background writes.
  NomadFi never flips `isTaxDeductible` on the user's behalf.
- `[x]` **Education starter** (Phase 7A) — locally-authored catalogue under
  `Core/Services/TaxEducation/` covering United States (3 lessons + 1
  checklist), Canada (3 lessons + 1 checklist), and Trinidad and Tobago
  (2 lessons + 1 checklist). Every lesson cites at least one official source
  from `docs/README.md` (IRS Pub 519, IRS foreign-students hub, 1040-NR +
  Form 8843 pages, CRA residency / student / TFSA / RRSP pages,
  BIR / Ministry of Finance / FIUTT pages). Each lesson is structured as
  *what it is → why it matters → what to review next → official sources →
  escalation note*. Deterministic region selection under
  `TaxEducationSelector` honours home jurisdiction first, de-duplicates
  repeated codes, and silently skips regions the catalogue does not yet
  cover. Surfaced inside `TaxVaultView` as the **Learn for your
  jurisdictions** section; lesson detail opens in a sheet with
  external-source links. _Evidence: `TaxEducationCatalogTests.swift`,
  `TaxEducationSelectorTests.swift`._
- `[x]` **Education progression** (Phase 7B) — persisted, CloudKit-safe
  `TaxEducationProgressRecord` `@Model` (all fields optional /
  defaulted, no `@Attribute(.unique)`, no relationships) tracks
  lesson-reviewed state and checklist-item completion explicitly.
  Pure `TaxEducationProgressService` exposes status lookup, per-region
  summaries, deterministic next-step selection (first uncompleted
  checklist item → first uncompleted lesson → nil), and explicit
  `markLessonReviewed` / `unmarkLessonReviewed` / `toggleChecklistItem`
  writes. Registered in `NomadFiApp.modelContainer`,
  `SwiftDataTestContainerFactory.fullAppSchema`, and
  `DataGovernancePolicy.deleteAllUserData`. UI surfaces: per-region
  "X of Y steps reviewed" chip, a calm "Next to review" card inside
  each region block, interactive checklist checkboxes, lesson-row
  "Reviewed" badges, and an explicit Mark / Unmark action in the
  lesson detail sheet. No auto-complete on lesson open — every
  transition is an explicit user action. _Evidence:
  `TaxEducationProgressServiceTests.swift`._
- `[x]` **Region-aware knowledge-check quizzes** (Phase 7C) —
  locally-authored quizzes under `Core/Services/TaxEducation/Quiz/`
  (`TaxEducationQuizCatalog`, `TaxEducationQuizScoring`,
  `TaxEducationQuiz` + `Question` + `Option` + `Result`). One
  quiz per supported region (U.S. / Canada / Trinidad and Tobago),
  3 questions each, single-answer MC, every question cites an
  existing lesson via `sourceLessonID`. No new source coverage.
  Persistence re-uses the Phase 7B `TaxEducationProgressRecord`
  with a `.quiz` kind and four new optional / defaulted fields
  (`quizID`, `quizScorePercent`, `quizCorrectCount`,
  `quizQuestionCount`) — CloudKit-safe, no new `@Model`. Unlocks
  only after every lesson and every checklist item for the region
  is completed; pass threshold 80 %; retakes overwrite the
  single record for the (region, quizID) tuple. Surfaced as a
  **Knowledge check** row inside each region block with four
  visual states (locked / ready / needs review / passed), a
  `TaxEducationQuizSheet` for taking the quiz, and deterministic
  fall-through from checklist → lessons → quiz in the "Next to
  review" pointer. _Evidence:
  `TaxEducationQuizCatalogTests.swift`,
  `TaxEducationQuizScoringTests.swift`,
  `TaxEducationQuizServiceTests.swift`._
- `[x]` **Tax Vault IA refresh + calm recognition badges** (Phase 7D) —
  the monolithic Tax Vault list split into three peer surfaces under
  one segmented switcher: **Review** (in-content scan CTA plus the
  tax-category suggestion queue), **Learn** (education starter,
  progression, quizzes, recognition strip), **Archive** (searchable
  year / jurisdiction list with per-year exports). Recognition
  lives under `Core/Services/TaxEducation/Recognition/`
  (`TaxEducationRecognitionKind`, `Badge`, `Summary`,
  `Computer`) and is purely derived — no new persistence, no
  points, no levels, no gamified spectacle. Five starter badges:
  `.firstStepReviewed`, `.starterReviewed(region)`,
  `.knowledgeCheckPassed(region)`, `.regionReviewed(region)`,
  `.multiRegionReviewed`. Badges disappear automatically when
  the user regresses progress. _Evidence:
  `TaxEducationRecognitionComputerTests.swift`,
  `TaxVaultSurfaceTests.swift`._

### Still to build

- Deeper investment-account lessons (IRA for the U.S., TFSA/RRSP for Canada
  beyond the high-level starter).
- Receipt and document organization prompts tied to the education
  checklists.

### Do Not Build

- Final tax-residency determinations without user confirmation and official
  source-backed flow.
- Personalized tax filing advice.
- Immigration/legal advice.

### Tradeoff

Education and preparation are high-value and lower risk. Automated tax advice
requires more source coverage, disclaimers, and potentially professional review.

---

## Phase 8 — Investment Education and Index Fund Tracking

**Status:** `[ ]` Planned.

**Goal:** Help users learn and track long-term investing without becoming an
unregistered investment advisor.

### Build

- Index-fund education:
  - what an index fund is
  - S&P 500 basics
  - diversification
  - expense ratios
  - currency exposure
  - account type fit
  - risk and time horizon
- Watchlist and tracker for user-selected funds.
- Fee and allocation comparison.
- Official-source linking:
  - fund prospectus
  - issuer page
  - regulator/investor-protection sources
- Clear distinction between education and recommendation.

### Do Not Build Initially

- "Tell me exactly which fund to buy." (`[!]` Deferred by product rule.)
- Automated portfolio advice. (`[!]` Deferred by product rule.)
- Suitability recommendations. (`[!]` Deferred by product rule.)
- Guaranteed-return framing. (`[!]` Deferred by product rule.)

### Tradeoff

Investment education supports financial leverage and social impact, but direct
investment recommendations can create regulatory risk. Start with literacy,
tracking, and transparent comparisons.

---

## Phase 9 — AI and Machine Learning Layer

**Status:** `[ ]` Planned. Nothing in the app runs a language model today;
every decision is deterministic.

**Goal:** Make NomadFi feel intelligent while preserving financial rigor.

### AI Responsibilities

- Parse natural-language requests into structured scenario inputs.
- Ask clarifying questions when required data is missing.
- Explain deterministic recommendations in plain language.
- Summarize tradeoffs.
- Generate learning content from verified source material.
- Convert receipts and statements into structured records where user confirms
  the result.

### ML Responsibilities

- Merchant categorization.
- Recurring transaction detection.
- Spend anomaly detection.
- Tax-category suggestions.
- Duplicate transaction detection.
- Travel/home context inference.
- Merchant-location matching.

### AI Must Not

- Invent source-backed facts. `[!]` Deferred indefinitely.
- Replace official issuer, regulator, or tax sources. `[!]` Deferred
  indefinitely.
- Guarantee score outcomes. `[!]` Deferred indefinitely.
- Recommend carrying balances. `[!]` Deferred indefinitely.
- Recommend securities as personalized investment advice. `[!]` Deferred
  indefinitely.
- Make final tax or immigration determinations. `[!]` Deferred indefinitely.

### Tradeoff

AI creates the differentiated product experience. Deterministic rules and
citations preserve trust.

---

## Phase 10 — Optional Apple Pay and Wallet Features

**Status:** `[!]` Deferred. Add only if a concrete product need appears — see
the matrix above.

**Goal:** Add Apple Pay or Wallet only when a clear product need appears.

### Apple Pay Use Cases

Add Apple Pay only if NomadFi needs:

- subscription checkout
- donations
- paid reports
- premium financial education modules

### Wallet Pass Use Cases

Consider Wallet passes only if NomadFi needs:

- a NomadFi membership pass
- a student financial-health badge
- an event/workshop pass
- a saved learning credential

### Do Not Use Wallet For

- trying to read all user cards
- trying to scrape transaction history
- replacing FinanceKit
- replacing card/account data the user entered

### Tradeoff

Wallet and Apple Pay can improve polish later, but using them now would distract
from the core product and would not solve card recommendation or transaction
tracking.

---

## Current Build Order

Each item shows status relative to the code in this repo, not an aspirational
plan. Shipped items stay listed so future phases can build on them without
re-debating whether the foundation exists.

1. `[x]` Source governance and product mission in place.
2. `[x]` Account profiles, snapshots, and credit limits modelled honestly.
3. `[x]` Credit-card statement calendar and user-confirmed schedule gating.
4. `[x]` Local statement-close and payment-due reminders.
5. `[x]` Deterministic Scenario 1 — Amazon arrival-order brief.
6. `[x]` Modernised App Intents + App Shortcuts pointed at the Decision
   Assistant (no deprecated APIs, no FX-fee-only answers).
7. `[x]` Decision Draft intake, lifecycle (create / edit / archive / restore /
   delete), and Siri capture.
8. `[x]` Deterministic Credit Timing v1 (portfolio-wide readiness).
9. `[x]` Generic Purchase Decision Engine v1 (`PurchaseDecisionEngine`) with
   per-account stances, FX-verification caveats, no rewards ranking, and an
   in-app brief sheet.
10. `[x]` `RecommendCardIntent` (voice surface on top of the generic
    engine) and `ReviewCreditTimingIntent` (voice surface on top of
    the credit-timing engine). Both run `.background`, cite the
    engines' existing deterministic output, never invent rewards
    or predict credit-score outcomes.
11. `[x]` Verified rewards / category-bonus model on `Account`
    (`RewardProfile`, `RewardRateEvaluation`, `RewardUnit`,
    `CreditCardRewardsEditView`) — rewards now enter the ranking
    only when verified + fresh + unit-comparable.
12. `[x]` Transaction capture fan-out (Phase 4): CSV import, merchant
    normalisation, deterministic dedupe
    (`Core/Services/Import/` + `TransactionImportView`), a
    generalised `RecurringChargeDetector` that the existing
    Subscriptions surface now delegates to, and a read-only
    Dashboard spending-trend card
    (`SpendingTrendComputer` + `SpendingTrendCard`). Follow-ups
    (tax-category suggestions, spend anomaly detection, merchant
    categorisation ML) remain scoped to later phases.
13. `[x]` Phase 6 — Credit Leverage and Payment Timing, complete.
    6A: Cross-card payment-allocation planner
    (`CreditPaymentAllocationPlanner`) and credit-limit-increase
    readiness checklist (`CreditLimitReadinessEvaluator`). 6B:
    `CreditTimingSpendingContextBuilder` projects the Phase 4
    trend summary into a read-only **Recent spending context**
    section on the Credit Timing brief. All three are pure
    value-layer services under
    `Features/DecisionAssistant/CreditTiming/`; none modifies
    paydown targets or promises an issuer-side outcome.
14. `[~]` Phase 7 — Tax Vault education. Entry: tax-category
    suggestion bridge (`Core/Services/TaxSuggestions/`,
    `Features/TaxVault/Suggestions/`). 7A: locally-authored
    source-backed education starter (`Core/Services/TaxEducation/`,
    `Features/TaxVault/Education/`) with checklists + lessons for
    United States / Canada / Trinidad and Tobago, driven by the
    user's active jurisdictions (home first). 7B: persisted user
    progress — `TaxEducationProgressRecord` `@Model` plus a pure
    `TaxEducationProgressService` powering explicit Mark-reviewed
    / checklist-toggle actions, per-region "X of Y steps reviewed"
    chips, and a deterministic Next-to-review pointer. 7C:
    region-aware **knowledge-check quizzes** under
    `Core/Services/TaxEducation/Quiz/` with explicit submit +
    retake, deterministic 80 %-pass scoring, unlock after the
    checklist and lessons are completed, and quiz-aware
    next-step / summary logic — same `TaxEducationProgressRecord`,
    four new optional fields, no new `@Model`. 7D: Tax Vault IA
    refresh into **Review / Learn / Archive** peer surfaces via a
    segmented switcher, in-content scan CTA on Review, and calm
    current-state recognition badges under
    `Core/Services/TaxEducation/Recognition/` — purely derived,
    no new persistence. Deeper investment-account lessons and
    receipt / document organisation prompts remain as follow-ups.
15. `[~]` Phase 5 — provider-neutral financial-data architecture.
    5A: abstraction + coordinator + adapters under
    `Core/Services/FinancialData/` (manual / CSV / FinanceKit /
    external-aggregator placeholder). 5B: reconciliation layer
    (`FinancialDataReconciler`, `FinancialDataReconciliationResult`),
    CloudKit-safe provider-link fields on `Account` + a provider-
    neutral `providerKindRawValue` on `Transaction`, and Settings →
    Financial Setup → **Financial Connections** with an explicit
    **Sync Now** action and a calm after-sync summary.
    `NSFinancialDataUsageDescription` added. Remaining: Apple-
    provisioned entitlement for real-device FinanceKit, background
    delivery hook, and a concrete third-party aggregator bakeoff
    behind the existing placeholder adapter.
16. `[ ]` Investing education and index-fund tracking (Phase 8).
17. `[!]` Apple Pay — only if NomadFi starts accepting payments.
18. `[!]` Wallet passes — only if NomadFi ships a pass with concrete user
    value.

---

## Current Next Step

**Phase 5 provider architecture (5A) and reconciliation + Financial
Connections UI (5B) are live.** NomadFi now exposes a provider-neutral
layer (`Core/Services/FinancialData/`) that keeps manual and CSV as
first-class fallbacks, wraps FinanceKit with typed availability /
authorization / mapping seams, and pins a placeholder boundary for a
later third-party aggregator. Syncs run only in response to an
explicit **Sync Now** action in Settings → Financial Setup →
**Financial Connections**, and the reconciliation result is rendered
honestly instead of as a universal-coverage claim.

Highest-leverage remaining work, in order:

- **FinanceKit managed entitlement + real-device bakeout** —
  provision `com.apple.developer.finance-kit` with Apple, finish the
  `FinanceStore.accounts(query:)` / `transactions(query:)` paths in
  `FinanceKitFinancialDataProvider`, and verify on a supported
  account (Apple Card / Apple Cash / Apple Savings in the US; UK
  open-banking institutions where available). Background-update
  registration lands behind the same entitlement.
- **Third-party aggregator provider bakeoff** — land a concrete
  adapter (Plaid / MX / Akoya / Finicity or a direct FDX/FAPI
  integration) behind the existing
  `ExternalAggregatorFinancialDataProvider` seam. Keep vendor SDK
  imports confined to the adapter file; feed the reconciler through
  the same `FinancialDataSyncReport` contract.
- **Phase 8 investing education + index-fund tracking** — still the
  next net-new Learn surface once the financial-data layer has a
  live upstream.
- **Deeper investment-account lessons** (IRA / TFSA / RRSP) and
  **receipt / document organisation prompts** remain open as Tax
  Vault follow-ups but are explicitly lower priority than the
  provider work above.

---

## Source Anchors

- Apple PassKit: `https://developer.apple.com/documentation/passkit`
- Apple Wallet: `https://developer.apple.com/documentation/passkit/wallet/`
- Apple FinanceKit: `https://developer.apple.com/documentation/financekit`
- Apple FinanceKit overview and requirements:
  `https://developer.apple.com/financekit/`
- Apple Pay capability checks:
  `https://developer.apple.com/documentation/passkit/pkpaymentauthorizationcontroller/canmakepayments%28%29`
- Apple Human Interface Guidelines:
  `https://developer.apple.com/design/human-interface-guidelines`
- Apple Design Awards:
  `https://developer.apple.com/design/awards/`
