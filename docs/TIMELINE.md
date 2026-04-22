# NomadFi Product Timeline

Phased roadmap for turning NomadFi into a cross-border financial decision
assistant. This document intentionally accounts only for what NomadFi needs to
help users choose payment methods, protect credit leverage, reduce FX waste,
and learn jurisdiction-aware tax and investing concepts; it does not assume
Apple Pay or Wallet should be used just because they are available.

This file is public-safe. It must not duplicate private personal facts from
`docs/ARIEL.md`.

---

## Mission Anchor

NomadFi helps cross-border students, temporary residents, interns, immigrants,
and other multi-country earners make better financial decisions without
requiring full manual bookkeeping.

In one sentence:

> NomadFi is a cross-border financial decision engine that helps users maximize
> rewards, avoid debt, reduce FX waste, protect credit health, and learn tax and
> investing strategy using verified, privacy-preserving financial context.

This roadmap is governed by [`docs/MISSION.md`](./MISSION.md). Features that do
not advance the decision-assistant mission should be delayed, demoted to
optional tools, or removed from primary navigation.

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

**Goal:** Make NomadFi useful without external account aggregation.

### Current Sub-Phase: Decision Draft Lifecycle v1

Building on Decision Draft Intake v1, this refinement gives users
full control over the raw context they capture. `DecisionDraftFormView`
now serves both creation and edit modes: `init()` starts a new draft,
`init(draft:)` pre-populates fields and mutates the same record on
save (preserving `createdAt`, refreshing `updatedAt`). `DecisionDraftDetailView`
surfaces an **Edit** primary toolbar button plus a **More actions**
menu with **Archive** / **Restore** and a destructive **Delete draft…**
path guarded by `confirmationDialog`. All lifecycle mutations route
through the pure `DecisionDraftStore` namespace so the UI never
touches SwiftData directly.

The Decision Assistant now runs two SwiftData queries: one for
active (`needsEngine`) drafts, one for archived. Archived drafts
render in a quieter secondary **Archived drafts** section that only
appears when non-empty. Active, archived, and analyzed decisions
stay visually separate — drafts remain outside `DecisionCatalog`
and are never promoted to analyzed decisions.

Privacy posture is unchanged and strengthened by per-draft delete:
users no longer need a full "delete all data" wipe to remove an
accidentally sensitive capture.

### Previous Sub-Phase: Decision Draft Intake v1

After the App Intents hardening landed, the Decision Assistant's
**Gather intelligence** section gained a real capture flow. Users
can save a future scenario in their own words: `DecisionDraftRecord`
is a SwiftData model that stores a title, a free-form scenario
body, a user-chosen `DecisionDraftKind`, optional merchant/location/
timing/amount/notes fields, and a `DecisionDraftStatus` that starts
at `needsEngine`. Drafts render in a dedicated **Gathered intelligence**
section — visually distinct from **Previous decisions** — so the user
can never mistake a raw capture for an analyzed decision.

Non-goals for this sub-phase are intentionally strict: no generic AI
analyzer, no second deterministic engine, no Apple Intelligence, no
reinforcement learning, no Apple Pay / Wallet / FinanceKit dependency,
and no tax / investment / credit-score predictions derived from
drafts. Drafts are raw user-provided context, period. When a future
deterministic engine ships for a kind, drafts of that kind become
candidates for analysis.

Privacy posture is unchanged: drafts stay on-device (SwiftData, no
network), the capture form warns against entering account numbers
or full addresses, and `DataGovernancePolicy.deleteAllUserData`
wipes `DecisionDraftRecord` alongside every other user record.

### Sub-Phase: Decision Assistant as the Core Surface

The Decision Assistant (bottom tab: **Decisions**) is now NomadFi's
core product surface. It hosts the Active Decision (Scenario 1 — Amazon
arrival order today), Previous Decisions, and **Gathered intelligence**
(captured drafts awaiting a deterministic engine). All recommendations
continue to come from NomadFi's deterministic, source-backed engines.

Subscriptions, Ledger, and Tax Vault moved to Settings → Advanced Tools.
They stay fully functional — they're just no longer primary tabs until
an automatic-aggregation or stronger tax-planning flow exists.

### Sub-Phase: Account Profiles + Live Snapshots (still in flight)

This sub-phase separates stable account profile data (credit limit, account
type, currency, jurisdiction) from volatile live amounts (current balance,
available credit, statement balance). Profiles are entered once; live amounts
are stored as optional, timestamped snapshots — never as stable facts. Credit
limits are explicitly modelled as capacity, not as balances, and are never
counted as net worth. Credit cards without a saved current-balance snapshot
are excluded from net worth and labelled "not counted" rather than treated
as zero debt.

This lands before any automatic aggregation so that when FinanceKit,
imports, or other live sources arrive later, they write into a model that
already represents snapshots honestly.

### Build

- User-managed accounts and cards as stable profile records.
- Account-type-aware amount entry (credit card: credit limit, current
  balance, available credit; non-credit: optional current balance).
- Timestamped, source-labelled live snapshots with stale/unknown markers.
- Credit-card statement close dates and payment due dates.
- Card-level foreign-transaction-fee provenance.
- Exchange-rate provenance and freshness labels.
- Scenario-specific decision engines, starting with real cross-border purchase
  cases. Scenarios may read the linked card's saved snapshot but never
  assume snapshot values are live.
- Local notifications for statement close and payment due dates.
- Clear privacy controls and complete local data wipe.

### Why This Comes First

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

**Goal:** Let the user ask for a card recommendation in natural language.

### Current Sub-Phase: App Shortcuts aligned with Decision Assistant

The Siri / App Shortcuts surface now routes into the Decision Assistant
and Scenario 1 engine instead of answering from foreign-transaction-fee
sorting alone. Shortcuts ship with deliberately honest phrasing:

- **Open Decision Assistant** — a navigation-only intent that opens the
  app on the Decisions tab.
- **Review Amazon Arrival Decision** — a voice-first summary that reads
  the saved Scenario 1 record, runs `ScenarioDecisionEngine`, and
  speaks the current ruling plus outstanding-check count.
- **Continue Amazon Arrival Decision** — opens the app on the Decisions
  tab and speaks a short scene-setter carrying the engine's ruling.
- **Which Card Should I Use?** — legacy phrase kept for discoverability,
  but the intent now defers to the Scenario 1 engine. It explicitly
  states that NomadFi cannot yet answer a merchant-agnostic card
  question and directs the user to the Amazon arrival-order decision.

No generic scenario parser, Apple Intelligence integration, or
reinforcement-learning layer is shipped in this sub-phase — only the
deterministic routing. Tab deep-linking is done with a persisted
`MainTabSelection` that App Intents write to `UserDefaults` before
the system brings NomadFi to the foreground.

All intents have been modernized to the iOS 18+ `supportedModes`
API; the deprecated `openAppWhenRun` flag is gone from the codebase.
Navigation intents (`OpenDecisionAssistantIntent`,
`ContinueAmazonArrivalDecisionIntent`) declare
`.foreground(.immediate)` so the `UserDefaults` write happens against
the foregrounded host process and the Decisions tab is the first
surface the user sees. Voice-only intents (`ActiveCardIntent`,
`ReviewAmazonArrivalDecisionIntent`, and the supporting
`CheckBudgetIntent` / `CheckNetWorthIntent` / `LogExpenseIntent`)
declare `.background` — they never need to bring the app forward.
App Shortcuts metadata extraction is confirmed in the main app
target's `Metadata.appintents` bundle on every build.

### Example User Request

"I am in San Francisco at Target, buying groceries for this week's meal prep,
and I need to know which card I should use and how I should approach this."

### Build

- An App Intent such as `RecommendCardIntent`.
- Inputs:
  - merchant name
  - purchase category
  - amount
  - currency
  - location context
  - travel / home / internship mode
  - optional urgency notes
- Output:
  - recommended card or payment method
  - reason
  - confidence label
  - required checks
  - deadline if statement close or due date matters
  - fallback option

### Decision Inputs

- Card availability.
- Current balances and limits.
- Statement close dates.
- Payment due dates.
- FX fees.
- Rewards category.
- User's jurisdiction and current country.
- Current spending trend.
- Purchase category.
- Verified vs. unverified source status.

### Tradeoff

Siri gives the product a strong interaction model before automatic financial
data aggregation exists. The limitation is that the answer is only as good as
the data NomadFi already has.

---

## Phase 3 — Context-Aware Card Decision Engine

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

**Goal:** Improve spending intelligence before FinanceKit is available.

### Build

- Better manual transaction entry.
- Receipt scanning and confirmation.
- CSV import for bank/card exports.
- Transaction deduplication.
- Merchant normalization.
- Recurring charge detection.
- Spending trend summaries.
- Tax-category suggestions with clear confidence labels.

### Optional Later

- Email receipt import, only if privacy and permissions can be handled well.
- Bank export parsing by institution.
- On-device merchant-category ML.

### Tradeoff

CSV/manual capture is less automatic than live bank feeds, but it avoids paid
aggregators, broad credential access, and unavailable Wallet data.

---

## Phase 5 — FinanceKit Evaluation and Adapter

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

**Goal:** Help users build credit without debt.

### Build

- Statement close reminders.
- Payment due reminders.
- Current utilization projection.
- Available credit guardrails.
- Near-limit warnings.
- "Pay before close" planning where issuer reporting assumptions are clearly
  caveated.
- Payment allocation suggestions across cards.
- Credit-limit-increase readiness checklist.

### Intelligence Needed

- Current balance.
- Available credit.
- Total credit limit.
- Statement close date.
- Due date.
- Recent spend trend.
- Whether the user can pay before the statement closes.
- Whether data is verified or stale.

### Tradeoff

NomadFi can help users behave in ways generally associated with stronger credit
profiles, but it must not promise a score increase or a credit-limit increase.
Credit scoring and issuer risk models are proprietary.

---

## Phase 7 — Tax Efficiency Education

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

- "Tell me exactly which fund to buy."
- Automated portfolio advice.
- Suitability recommendations.
- Guaranteed-return framing.

### Tradeoff

Investment education supports financial leverage and social impact, but direct
investment recommendations can create regulatory risk. Start with literacy,
tracking, and transparent comparisons.

---

## Phase 9 — AI and Machine Learning Layer

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

- Invent source-backed facts.
- Replace official issuer, regulator, or tax sources.
- Guarantee score outcomes.
- Recommend carrying balances.
- Recommend securities as personalized investment advice.
- Make final tax or immigration determinations.

### Tradeoff

AI creates the differentiated product experience. Deterministic rules and
citations preserve trust.

---

## Phase 10 — Optional Apple Pay and Wallet Features

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

## Recommended Build Order

1. Finish local card schedule reminders.
2. Build the Siri/App Intent "Recommend Card" flow.
3. Improve the scenario engine so it can handle arbitrary merchant/category
   inputs, not only Scenario 1.
4. Add transaction import and merchant categorization.
5. Add credit-leverage planning around utilization, payment timing, and
   statement close dates.
6. Add tax education modules by region.
7. Add index-fund education and tracking.
8. Evaluate FinanceKit entitlement and adapter design.
9. Add FinanceKit only if entitlement access and institution coverage justify
   the complexity.
10. Add Apple Pay only if NomadFi needs to accept payments.
11. Add Wallet passes only if a pass has a concrete user value.

---

## Current Best Next Step

The highest-leverage next feature is a Siri/App Intent card recommendation
flow:

> "I am in San Francisco at Target, buying groceries for this week's meal prep.
> Which card should I use?"

This should return:

- recommended card or payment method
- confidence label
- source-backed rationale
- payment timing warning if statement close matters
- utilization warning if credit limit or balance matters
- FX warning if away from home jurisdiction
- fallback option
- missing data checklist

This path is free, robust, privacy-preserving, technically feasible, and aligned
with NomadFi's long-term AI vision.

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
