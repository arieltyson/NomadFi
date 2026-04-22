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
- [~] "Which card should I use?" — routed through Scenario 1 honestly but
  not yet answering arbitrary merchant / category questions. See Phase 3.
- [ ] Generic merchant / category scenario engine.
- [ ] Cross-card payment-allocation planning.
- [ ] Credit-limit-increase readiness checklist.

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
- [ ] `ReviewCreditTimingIntent` (background voice review of Credit Timing).
- [ ] `RecommendCardIntent` for generic merchant / category questions
  (blocked on the generic scenario engine).

### Transaction capture / aggregation

- [~] Manual transaction entry — `Features/Ledger/AddTransactionView.swift`
  exists; demoted to Settings → Advanced Tools until a decision surface
  needs it.
- [~] Receipt scanning — `ReceiptScannerService`, `ReceiptCategorizer`,
  `TaxVault` flows exist; still kept in Advanced Tools.
- [ ] CSV import for bank/card exports.
- [ ] Merchant normalisation.
- [ ] Merchant categorisation ML.
- [ ] Recurring charge detection across the portfolio (Subscriptions
  detection exists as a separate flow — `SubscriptionDetector` — for
  that specific domain).
- [ ] Spend anomaly detection.

### Tax and investing education

- [~] Tax Vault (document storage, receipt capture) exists but is a
  passive archive — not an education module.
- [ ] Gamified tax education path (Canada / U.S. / Trinidad and Tobago).
- [ ] Investing education + index-fund tracking.

### Apple capability tracks

- [ ] FinanceKit evaluation + adapter.
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

**Status:** `[ ]` Planned. This is the next major engineering target (see
[Current Next Step](#current-next-step)). Scenario 1 is the only concrete
precedent.

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

**Status:** `[~]` Partially shipped. Manual transaction entry and receipt
scanning exist as optional tools in Advanced Tools; CSV import, merchant
normalisation, and categorisation ML are not implemented.

**Goal:** Improve spending intelligence before FinanceKit is available.

### Already shipped

- `[x]` Manual transaction entry (`Features/Ledger/AddTransactionView.swift`).
- `[x]` Receipt scanning and confirmation (`ReceiptScannerService`,
  `ReceiptCategorizer`, Tax Vault flows).
- `[x]` Subscription detection (`SubscriptionDetector`, separate flow
  scoped to subscriptions).

### Still to build

- `[ ]` CSV import for bank/card exports.
- `[ ]` Merchant normalisation.
- `[ ]` Transaction deduplication across sources.
- `[ ]` Recurring-charge detection beyond the Subscriptions flow.
- `[ ]` Spending trend summaries.
- `[ ]` Tax-category suggestions with confidence labels.

### Optional later

- Email receipt import, only if privacy and permissions can be handled well.
- Bank export parsing by institution.
- On-device merchant-category ML.

### Tradeoff

CSV/manual capture is less automatic than live bank feeds, but it avoids paid
aggregators, broad credential access, and unavailable Wallet data.

---

## Phase 5 — FinanceKit Evaluation and Adapter

**Status:** `[ ]` Planned. Not started in code; the abstraction will land once
Phase 4 has a working manual/CSV provider to serve as the fallback.

**Goal:** Add Apple-native financial data only if it materially improves the
app and Apple grants access.

### Build

- A `FinancialDataProvider` abstraction.
- Provider implementations:
  - manual provider
  - CSV import provider
  - future FinanceKit provider
- A FinanceKit feasibility document:
  - entitlement requirements
  - supported countries
  - supported account types
  - user-consent flow
  - data fields available
  - gaps for non-supported institutions

### Use FinanceKit For

- Supported account discovery.
- Supported balances.
- Supported transactions.
- Background delivery where available and approved.

### Do Not Use FinanceKit For

- Unsupported institutions.
- Tax advice by itself.
- Investment recommendations by itself.
- Credit-score predictions.
- Any path that breaks if entitlement is denied.

### Tradeoff

FinanceKit can make NomadFi feel much more automatic, but depending on it too
early creates entitlement, coverage, and review risk.

---

## Phase 6 — Credit Leverage and Payment Timing

**Status:** `[~]` Partially shipped. Statement-close reminders, payment-due
reminders, utilization banding, near-limit guidance, and per-card paydown
targets are live (Credit Timing v1). Cross-card payment allocation and a
credit-limit-increase readiness checklist are still outstanding.

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

### Still to build

- `[ ]` Payment allocation suggestions across multiple cards.
- `[ ]` Credit-limit-increase readiness checklist.
- `[ ]` Spend-trend context inside Credit Timing (depends on Phase 4).

### Tradeoff

NomadFi can help users behave in ways generally associated with stronger credit
profiles, but it must not promise a score increase or a credit-limit increase.
Credit scoring and issuer risk models are proprietary.

---

## Phase 7 — Tax Efficiency Education

**Status:** `[ ]` Planned. A Tax Vault storage surface exists as an Advanced
Tool, but no education path ships yet.

**Goal:** Teach region-specific tax concepts without crossing into professional
tax advice.

### Build

- A gamified learning path for:
  - Canada: TFSA, RRSP, residency basics, student considerations.
  - United States: IRA basics, nonresident vs. resident alien concepts,
    student/intern tax filing reminders.
  - Trinidad and Tobago: local tax and investment-account basics.
- Region-specific checklists.
- Source-backed lessons using CRA, IRS, and official T&T sources.
- Receipt and document organization prompts.
- "Ask a professional" escalation points.

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
9. `[ ]` **Next:** Generic merchant / category scenario engine (see Current
   Next Step below).
10. `[ ]` `RecommendCardIntent` on top of the generic engine, plus the
    small `ReviewCreditTimingIntent` voice parity.
11. `[ ]` Transaction capture fan-out: CSV import, merchant normalisation,
    recurring-charge detection beyond Subscriptions.
12. `[ ]` Cross-card payment-allocation planning and credit-limit-increase
    readiness checklist (completes Phase 6).
13. `[ ]` Region-specific tax education path (Phase 7).
14. `[ ]` Investing education and index-fund tracking (Phase 8).
15. `[ ]` FinanceKit evaluation + adapter (Phase 5) — gated on entitlement
    access and institution coverage.
16. `[!]` Apple Pay — only if NomadFi starts accepting payments.
17. `[!]` Wallet passes — only if NomadFi ships a pass with concrete user
    value.

---

## Current Next Step

**Target:** a generic merchant / category scenario engine (Phase 3) —
specifically, the pure, deterministic value types and engine that will let
NomadFi answer "Which card should I use at <merchant> for <amount>?" without
inventing data.

**Why this over the alternatives:**

- It is the single biggest honesty gap. The voice surface already has to say
  *"NomadFi can't yet answer which card to use for any merchant"* (see
  `ActiveCardIntent`). Closing this gap is the clearest user-visible win.
- `RecommendCardIntent` is blocked on it — the Siri phrase is free once the
  engine exists.
- It reuses the foundations we just shipped: `Account` snapshots, `CreditCardSchedule`,
  the `SourceProvenance` evidence model, and the `ScenarioCitation` pattern
  from Credit Timing and Scenario 1. No new data model is required for v1.
- It keeps the "no generic AI" invariant — the engine stays deterministic and
  source-cited, matching the pattern that already passes tests.

**Scoping suggestion for a first slice:**

1. Define `MerchantCategory` (groceries, dining, travel, online-shopping,
   utilities, subscriptions, other) and a small `PurchaseContext` value type
   (merchant name, category, amount, currency, travel-mode, due-by).
2. Write a pure ranking engine that consumes `PurchaseContext` + `[Account]`
   and returns a structured recommendation: best option, why, when-not, fallback,
   source confidence. Apply the existing hard rules (no debt for rewards, no
   cash advance, no guarantees).
3. Lean on user-confirmed card terms only — never inferred issuer category
   bonuses. Unverified bonus categories surface as "needs verification" checks.
4. Surface as a new catalog entry / brief sheet; do not replace Scenario 1.
5. Follow up with `RecommendCardIntent` + the still-outstanding
   `ReviewCreditTimingIntent` (the smaller Credit Timing v1 follow-up).

Target tests mirror the shape of `CreditTimingDecisionEngineTests` and
`ScenarioDecisionEngineTests`: pin every claim, pin every refusal, pin
absolute-date phrasing, and pin the prohibited-vocabulary list.

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
