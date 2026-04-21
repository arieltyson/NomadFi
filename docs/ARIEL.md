# Ariel Financial Testbed

> **Purpose.** This document is the first personal-finance testbed baseline for
> NomadFi. My real, cross-border financial life is the ground truth used to
> evaluate and shape product behavior, scenario analysis, card optimization,
> foreign-exchange (FX) fee minimization, rewards maximization, credit-score
> improvement, debt avoidance, and tax-aware planning.
>
> **Scope.** Documentation only — no design or code changes are implied by this
> file. Nothing in this document is financial, tax, legal, or immigration advice.
>
> **Privacy.** This file intentionally excludes account numbers, government ID
> numbers, full addresses, employer names, school names, and any secrets. It may
> still contain sensitive personal context; it should not be published or
> committed to a public remote without an explicit privacy review.

---

## 1. Current Financial Testbed

### 1.1 Residency and Work Status

- **Citizenship:** Trinidad and Tobago.
- **Canada:** Temporary resident; international university student in Vancouver,
  BC, on a study permit / student visa.
- **United States:** Currently living in San Francisco for a 4-month internship
  on a J-1 visa.
- **Status summary:** Not a citizen or permanent resident of Canada or the
  United States.
- **Government identifiers held:**
  - A valid U.S. Social Security Number (SSN) — valid for work only with DHS
    authorization.
  - A valid Canadian Social Insurance Number (SIN).

### 1.2 Canada — Banking and Credit

Primary bank: **Canadian Imperial Bank of Commerce (CIBC)**, Vancouver, BC.

- **CIBC Dividend Cash Back credit card** — total credit limit: **CAD $5,000**.
- **CIBC chequing account.**
- **CIBC savings account.**
- **CIBC Advantage Debit Card** — linked to the chequing and savings accounts.

Additional Canadian credit:

- **American Express Cobalt credit card** — total credit limit: **CAD $12,000**.
  - Opened in Canada to build credit and earn rewards points.
  - Recently invited to upgrade to the **American Express Gold Card**.
  - Current Membership Rewards balance: **170,000+ points**
    _(optimal redemption strategy to be investigated later)._

### 1.3 Canada — Investing

**Wealthsimple** (opened in Canada, index-fund investing):

- Managed **Tax-Free Savings Account (TFSA)**.
- Self-managed **Tax-Free Savings Account (TFSA)**.

Under consideration: a **Wealthsimple card** if I stay in Canada long term.
_(To be explored later.)_

### 1.4 United States — Banking and Credit

Primary bank: **Chase Bank**.

- **Chase savings account.**
- **Chase Freedom Rise credit card** — used to pay U.S. expenses and build
  U.S. credit.
  - Current total credit limit: **USD $500**.
  - Purchase APR: **25.24%**.
  - Cash Advance APR: **28.49%**.
  - _APR values captured as of reference date **2026-04-22**; re-verify before
    acting on them._
- **Chase ATM card** — presumed to be ATM-cash-withdrawal only (to be
  confirmed with the bank).

**Payroll routing:** My U.S. internship salary (USD) is direct-deposited into
my **USD Wise account**, and I use those funds to pay down the Chase Freedom
Rise card.

### 1.5 United States — Chase Debit History

- I previously held a **Chase Visa debit card** and closed it when I left San
  Francisco last year ahead of a year away.
- On the bank clerk's recommendation, I maintained a **USD $300** balance in
  the Chase savings account to keep the account open until my return.
- Plan: on returning to San Francisco for 4 months this summer, **reopen the
  debit account and reactivate the debit card**.

### 1.6 Trinidad and Tobago

Minimal financial footprint (I left Trinidad and Tobago for university at age
19).

- One account with **Unit Trust Corporation**, with a card attached.
  - The card is **not** a credit card; its exact function is **unknown** and
    needs to be clarified with UTC.
- Under consideration: a **Trinidad and Tobago credit card**, possibly with
  CIBC. _(To be explored later.)_

### 1.7 Cross-Border / FX

**Wise** accounts and card:

- USD Wise account.
- CAD Wise account.
- Physical **Wise prepaid card** (green).

### 1.8 Short-Term Operating Goal

Minimize usage of the **Chase Freedom Rise** card so that the credit limit can
grow over time through issuer-initiated increases, while still keeping the card
active enough to continue building U.S. credit history.

---

## 2. Product Strategy Baseline

NomadFi should treat the ecosystem described in §1 as its **initial real-world
testbed** — a live, multi-jurisdiction account graph (Trinidad and Tobago,
Canada, United States) spanning credit, debit, chequing, savings, investing,
and multi-currency transfer rails.

Primary strategic objectives the product should optimize for:

- **Credit leverage.** Grow credit scores across applicable bureaus to unlock
  higher limits, better products, and lower borrowing costs.
- **Rewards maximization.** Evaluate points, cash-back, and redemption value
  (e.g., Amex Membership Rewards) on a real-yield basis.
- **Debt avoidance.** Never recommend behaviors that would cause the user to
  carry revolving credit-card debt.
- **FX-fee minimization.** Pick the payment rail that minimizes explicit fees
  _and_ the spread against the mid-market rate.
- **Tax-aware planning.** Where legally and appropriately possible, support
  decisions that lower taxable income (e.g., registered accounts) without
  giving tax advice.
- **Population fit.** Serve international students, temporary residents,
  interns, and cross-border earners as first-class users, not edge cases.
- **Scenario-driven recommendations.** Evaluate card choice and payment
  routing using the real spending scenarios captured in §4.

---

## 3. Research Standard

All future analysis and recommendations generated against this testbed must
follow the standard below.

- **Evidence hierarchy.** Prefer **scientific, peer-reviewed studies** where
  applicable. For market or product claims, rely on **data-backed research from
  credible sources** (central banks, regulators, bureau-published statistics,
  reputable industry analysts).
- **Source labeling.** Every recommendation must distinguish between:
  1. **User-provided facts** (captured in this document),
  2. **Verified product terms** (confirmed against current official issuer,
     bank, or regulator sources),
  3. **Inferred strategy** (model-generated reasoning built on top of 1 and 2).
- **Debt posture.** The app **must not** encourage carrying a credit-card
  balance for the sake of rewards, status, or credit-score signaling.
- **Freshness of terms.** APR, FX fees and spreads, rewards earn rates,
  tax treatment, residency implications, and account eligibility rules must be
  **re-verified against current official sources** before being used in a
  recommendation. Values in this document are snapshots and can go stale.
- **Uncertainty labeling.** When data is uncertain, stale, or user-provided but
  unverified, the app must **label it clearly** in the UI rather than presenting
  it as verified.
- **No fabricated citations.** If a claim cannot be backed by a real, citable
  source, it must be presented as an inference, not as a fact.

---

## 4. Scenario Log

A running log of real-world financial decisions used to test and refine
NomadFi's recommendations. Each entry should use the template below.

### Scenario Template

- **Date:**
- **Location:**
- **Purchase or financial decision:**
- **Amount:**
- **Currency:**
- **Available cards / accounts:**
- **Constraints:**
- **Recommended payment method:**
- **Reasoning:**
- **Reward impact:**
- **FX impact:**
- **Credit-utilization impact:**
- **Tax or reporting considerations:**
- **Follow-up questions:**

### Entries

_No scenarios logged yet. Append new entries below this line as they occur._

---

## 5. Open Questions

Tracked questions for future investigation. Each should be resolved against the
research standard in §3 before it influences a recommendation.

1. **Amex Cobalt → Gold.** Is upgrading from the American Express Cobalt to the
   American Express Gold Card optimal given current spend, travel patterns, and
   the 170,000+ Membership Rewards balance?
2. **Wealthsimple card.** Is a Wealthsimple card useful if I remain in Canada
   long term, and how does it compare to existing CIBC and Amex products for
   my real spending mix?
3. **Chase debit reactivation.** Does reopening the Chase debit account and
   reactivating the Visa debit card materially change my U.S. banking strategy
   versus routing everything through Wise + Chase Freedom Rise?
4. **Trinidad and Tobago credit card.** Should I pursue a Trinidad and Tobago
   credit card (potentially CIBC), and what benefit does a domestic credit file
   there provide given I live abroad?
5. **Wise routing.** How should Wise be used across CAD ↔ USD (and eventually
   TTD) flows to minimize FX cost while preserving optionality to pay cards in
   their native currency?
6. **Chase Freedom Rise optimization.** How do I use the Chase Freedom Rise
   card enough to keep building U.S. credit history and qualify for limit
   increases, while keeping utilization low and never carrying a balance at
   the stated 25.24% purchase APR?
7. **Cross-border tax and residency.** How do Canadian (study-permit),
   U.S. (J-1 intern), and Trinidad-and-Tobago (citizenship) residency and tax
   rules interact with this account and income structure, and which rules gate
   specific product recommendations?
