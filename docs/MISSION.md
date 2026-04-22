# NomadFi Mission

NomadFi is a cross-border financial decision assistant for international
students, temporary residents, interns, immigrants, and other people whose
financial lives span more than one country.

NomadFi helps users make better financial decisions without requiring full
manual bookkeeping.

---

## Mission Statement

NomadFi helps cross-border users maximize rewards, avoid debt, reduce FX waste,
protect credit health, and learn tax and investing strategy using verified,
privacy-preserving financial context.

The app is not trying to be a full ledger first. It is a decision engine that
uses the user's financial ecosystem, current context, and source-backed rules to
answer practical questions like:

- Which card should I use for this purchase?
- Should I pay in local currency or home currency?
- Will this purchase create high reported credit utilization?
- When should I pay before a statement closes?
- Which costs are coming from FX, issuer fees, or currency conversion markup?
- What tax or investing concept should I understand next for my jurisdiction?

---

## Product Identity

NomadFi is:

- a cross-border payment decision assistant
- a credit-leverage planning assistant
- an FX and fee-awareness engine
- a jurisdiction-aware financial setup guide
- a source-backed education layer for tax and investing basics
- a privacy-first financial context store

NomadFi is not:

- a manual ledger as the primary product
- a tax-preparation app
- an investment advisor
- a credit-score guarantee engine
- a bank account aggregator by default
- an Apple Wallet or Apple Pay wrapper

---

## Main Goals

### Choose the Best Card or Payment Method

NomadFi should help the user decide whether to use a U.S. credit card, Canadian
credit card, debit card, Wise balance, local account, or another method based
on:

- merchant and purchase category
- currency
- location and travel context
- foreign transaction fees
- rewards value
- available credit
- current balance snapshot
- statement close timing
- payment due timing
- source confidence and freshness

The product should always explain why a method is recommended and when the
recommendation should not be followed.

### Protect and Improve Credit Leverage

NomadFi should help users build stronger credit behavior without debt by
tracking and explaining:

- credit-card limits
- current balance snapshots
- available credit snapshots
- statement close dates
- payment due dates
- projected utilization
- near-limit risk
- payment timing
- stale or missing data

NomadFi must never recommend carrying a balance or paying interest to build
credit.

### Reduce Cross-Border Money Leakage

NomadFi should make hidden or confusing cross-border costs visible:

- foreign transaction fees
- dynamic currency conversion markups
- issuer exchange-rate spread
- Wise conversion costs
- subscription regional pricing differences
- card acceptance and fallback risk

The goal is to help users keep more of their money by understanding the real
cost of a transaction before they commit.

### Guide Financial Setup Across Jurisdictions

NomadFi should represent the user's financial ecosystem as stable profile data
plus optional live snapshots:

- jurisdictions
- accounts
- cards
- currencies
- statement calendars
- FX fee terms
- tax and residency context
- user-entered snapshots

The user should be able to update jurisdictions after onboarding. The user
should not need to delete the app, reset onboarding, or manually maintain every
changing balance to get value from NomadFi.

### Teach Tax and Investing Concepts Safely

NomadFi should teach region-specific financial concepts in a gamified,
source-backed way:

- Canada: TFSA, RRSP, tax residency basics, student considerations
- United States: IRA basics, J-1/nonresident concepts, filing reminders
- Trinidad and Tobago: local tax and investment-account basics
- investing: index funds, diversification, fees, risk, time horizon

All tax and investing content must be framed as education and planning context,
not professional tax, legal, immigration, or investment advice.

### Use AI as the Interface, Not the Source of Truth

NomadFi should eventually let the user ask natural questions, for example:

> I am in San Francisco at Target buying groceries for this week's meal prep.
> Which card should I use?

AI can parse the request, ask clarifying questions, summarize tradeoffs, and
explain the result. The recommendation itself must come from deterministic,
cited rules and known user context.

Voice entry points — Siri, App Shortcuts, and any future conversational
surface — follow the same rule. They must route into NomadFi's deterministic,
source-backed decision engines and must not answer financial questions from
generic heuristics (for example, foreign-transaction-fee ranking alone) or from
an LLM's free-form reasoning.

User-captured decision drafts (the **Gathered intelligence** section of the
Decision Assistant) are raw user-provided context, not recommendations. They
stay on-device, are labelled *needs engine*, and never receive an automatic
AI-generated answer. Drafts become candidates for analysis only when a
deterministic engine ships for their kind and the user opts in.

Users control the drafts they capture. Every draft can be edited, archived,
restored, or permanently deleted from its detail sheet — permanent delete is
always confirmed explicitly. NomadFi never needs a full data wipe to remove a
single mistyped or accidentally-sensitive draft.

Voice intake follows the same contract. Siri and App Shortcuts can capture
user-dictated scenarios as drafts on-device (status `needsEngine`), but voice
never triggers analysis or generates a recommendation. Captured drafts become
candidates for analysis only when a deterministic, source-backed engine ships
for their kind and the user opts in.

---

## Navigation Principle

Primary navigation should reflect the decision-assistant mission.

The bottom tab bar is exactly three surfaces:

- **Dashboard** — money context: global net worth, accounts, FX, and
  insights. It should never become a settings page or a ledger.
- **Decisions** (Decision Assistant) — the core product surface. Hosts the
  Active Decision, Previous Decisions, and future intake channels for
  typed scenarios, Siri / App Intents, and optional Apple Intelligence
  context. Recommendations come from NomadFi's deterministic,
  source-backed engines — never from a generic LLM.
- **Settings** — a concise hub for financial setup (jurisdictions,
  accounts, credit-card calendar), notifications, privacy & security,
  and the Advanced Tools subpage.

Companion tools such as **Subscriptions**, **Ledger**, and **Tax Vault**
live under Settings → Advanced Tools. They remain fully functional but
are not daily-driver tabs until automatic import / sync or stronger
decision-assistant flows make them central.

---

## Product Rules

- Do not require full manual transaction tracking for core recommendations.
- Do not treat unknown balances as zero.
- Do not treat credit limits as assets.
- Do not include credit limits in net worth.
- Do not make Apple Pay or Apple Wallet a dependency for card intelligence.
- Do not present AI-generated financial claims without source-backed evidence.
- Do not guarantee score increases, credit-limit increases, tax outcomes, or
  investment returns.
- Do not recommend debt, cash advances, or carrying balances for rewards.
- Do not duplicate private user testbed facts into public documentation.

---

## Success Standard

NomadFi succeeds when a user can describe a real-life financial situation and
receive a clear, source-aware recommendation that helps them:

- choose a payment method
- avoid unnecessary fees
- protect credit utilization
- avoid interest and missed payments
- understand jurisdiction-specific tradeoffs
- learn the next financial concept that matters

The product should feel intelligent because it is context-aware, not because it
pretends to know facts it has not verified.
