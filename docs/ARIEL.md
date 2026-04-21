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
> numbers, employer names, school names, payment-card numbers, and any secrets.
> As of the 2026-04-21 update, it does include **two physical addresses** —
> the owner's Canadian residential address and a temporary U.S. summer address
> — because they are load-bearing for cross-border delivery, tax, and
> residency scenarios captured in §4. These addresses must not be copied into
> `docs/README.md` or any other public-safe document, and this file must not
> be pushed to a public remote without an explicit privacy review. Treat the
> whole document as sensitive.

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

### 1.2 Current Address Context

Two physical addresses are in scope for the scenarios in §4. They affect
delivery country, sales-tax jurisdiction, billing-address checks, and which
card-issuer jurisdiction the merchant sees.

- **Canadian residential address:**
  `8888 University Dr, Burnaby, BC V5A 1S6, Canada`
- **Temporary U.S. summer address (upcoming internship stay):**
  `759 Devonshire Way, Sunnyvale, CA 94087, United States of America`

Notes:

- The Sunnyvale address is an Airbnb booked for the upcoming 4-month
  internship stay. Delivery to this address is possible before arrival only
  if the host permits package receipt; otherwise, deliveries should be timed
  for on or after arrival.
- A U.S. billing address has not yet been established at the Sunnyvale
  location; U.S. merchants may see a Canadian billing address tied to a
  Canadian card, which can affect AVS checks and fraud screening.
- Do not copy either address into public documentation.

### 1.3 Canada — Banking and Credit

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

### 1.4 Canada — Investing

**Wealthsimple** (opened in Canada, index-fund investing):

- Managed **Tax-Free Savings Account (TFSA)**.
- Self-managed **Tax-Free Savings Account (TFSA)**.

Under consideration: a **Wealthsimple card** if I stay in Canada long term.
_(To be explored later.)_

### 1.5 United States — Banking and Credit

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

### 1.6 United States — Chase Debit History

- I previously held a **Chase Visa debit card** and closed it when I left San
  Francisco last year ahead of a year away.
- On the bank clerk's recommendation, I maintained a **USD $300** balance in
  the Chase savings account to keep the account open until my return.
- Plan: on returning to San Francisco for 4 months this summer, **reopen the
  debit account and reactivate the debit card**.

### 1.7 Trinidad and Tobago

Minimal financial footprint (I left Trinidad and Tobago for university at age
19).

- One account with **Unit Trust Corporation**, with a card attached.
  - The card is **not** a credit card; its exact function is **unknown** and
    needs to be clarified with UTC.
- Under consideration: a **Trinidad and Tobago credit card**, possibly with
  CIBC. _(To be explored later.)_

### 1.8 Cross-Border / FX

**Wise** accounts and card:

- USD Wise account.
- CAD Wise account.
- Physical **Wise prepaid card** (green).

### 1.9 Short-Term Operating Goal

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

_Append new entries below this line as they occur._

### Scenario 1 — Initial Amazon.com Arrival Order for U.S. Summer Stay

- **Date recorded:** 2026-04-21
- **Storefront:** Amazon.com (U.S. storefront)
- **Delivery country:** United States
- **Delivery destination:** temporary U.S. summer address in Sunnyvale, CA
  (see §1.2)
- **Purpose:** pre-order initial essentials so no errands are required
  immediately after arriving at the Airbnb.
- **Available cards / accounts (pertinent):** Canadian American Express
  Cobalt (currently linked to Amazon account), Chase Freedom Rise (USD
  $500 limit), Wise USD account + Wise prepaid card, CIBC Dividend Cash
  Back (CAD, probably irrelevant for USD merchant).
- **Constraints:**
  - Goal of keeping Chase Freedom Rise utilization low to encourage
    issuer-initiated limit increases (see §1.9).
  - No independent U.S. billing address yet (see §1.2).
  - Order should be honest about what is verified vs. what still needs to
    be confirmed against current issuer terms.
- **Cart summary (from screenshots IMG_1459–IMG_1465, stored outside the
  repo, not committed):**
  - 14 items.
  - Amazon cart subtotal (pre-checkout, USD): **USD $352.65**.
  - Items include: Barebells Creamy Crisp protein bars (USD 61.98),
    Lifeway Low Fat Kefir (USD 3.66, with **overnight shipping** —
    USD 12.99 delivery charge, "Only 14 left"), Wyman's Wild Blueberry
    Powder (USD 34.99), Anova Sous Vide Precision Cooker Nano 2.0 (USD
    63.64), Navitas Organics Chia Seeds (USD 11.60), OWYN Pro Elite
    Protein Shake 12-pack (USD 40.99), Fitgriff Running Belt (USD 15.95),
    HEETA Scalp Massager (USD 9.99), NOW Pumpkin Seed Oil (USD 21.40),
    540 Titanium Derma Roller (USD 6.99), Nizoral Anti-Dandruff Shampoo
    (partially visible), plus the remaining items.
- **Checkout screenshot (Amazon Currency Converter enabled, pay in CAD):**
  - Items (14): **CAD 481.47**
  - Shipping & handling: **CAD 27.21**
  - Free shipping credit: **−CAD 9.47**
  - Total before tax: **CAD 499.21**
  - Estimated tax: **CAD 36.66**
  - Total: **CAD 535.87**
  - Gift card: **−CAD 68.01**
  - Exchange rate guarantee fee: **CAD 13.00**
  - **Order total (CAD, ACC enabled): CAD 480.86**
  - Alternative payment currency shown: **USD 342.67**
  - Amazon displayed exchange rate: **1 USD = 1.36528 CAD**
- **Delivery timing visible in screenshots:** most items deliver on or
  around **Sunday, 2026-04-26**; at least one item delivers **Monday,
  2026-04-27**; the Lifeway Kefir is the only overnight-shipping line.

#### Analysis — Payment Options to Compare

> **Labeling note.** Consistent with the evidence hierarchy in
> `docs/README.md`, every numeric claim below is one of:
> (a) **screenshot fact** — observed directly in the Amazon checkout on
> 2026-04-21; (b) **user-provided fact** — from this document's §1; or
> (c) **requires verification** — must be confirmed against the current
> official issuer/merchant source before acting on it. Nothing here is
> financial, tax, legal, or immigration advice.

##### Known facts

- Amazon.com USD checkout total: **USD 342.67** (screenshot).
- Amazon Currency Converter CAD total: **CAD 480.86** (screenshot),
  composed of an FX-converted CAD subtotal plus an explicit **CAD 13.00
  "exchange rate guarantee fee"** (screenshot).
- At Amazon's displayed rate (1 USD = 1.36528 CAD), USD 342.67 ≈
  **CAD 467.86** pre-fee, confirming that the CAD 480.86 total is
  equivalent to USD 342.67 **plus an ≈CAD 13.00 fee** — i.e.
  **≈3.79% extra** on top of Amazon's own displayed rate.
- Ariel's Chase Freedom Rise credit limit is **USD $500** (§1.5);
  USD 342.67 is **≈68.5%** of that limit before any existing balance.
- Ariel's short-term goal is to **minimize** Chase Freedom Rise
  utilization to encourage organic limit increases (§1.9).
- Ariel has a USD Wise account and a Wise prepaid card (§1.8).
- Amazon account payment currently defaults to the Canadian Amex Cobalt.

##### Unknowns to verify

Each item here must be verified against the stated official source before
the recommendation below is treated as final.

- **Amazon Currency Converter (ACC).** Exact disclosure of the
  "exchange rate guarantee fee" structure, whether the ≈3.79% observed
  here matches Amazon's stated rate-plus-fee, and whether declining ACC
  reliably routes the charge to the card-issuer's FX conversion.
  *Source: Amazon.com official Currency Converter help and terms pages.*
  **Not yet verified.**
- **Amex Canada — Cobalt foreign-currency conversion commission.**
  The exact percentage Amex Canada applies on top of their reference
  rate when a Canadian card is charged in a foreign currency.
  *Source: American Express Canada Cobalt Cardmember Agreement and
  pricing disclosures.* **Not yet verified.**
- **Amex Cobalt earn rate on Amazon.com.** Whether Amazon.com purchases
  earn 1x MR, or whether any category (e.g., groceries, eats and drinks)
  applies — many of the cart items are food, but online U.S. marketplace
  purchases rarely qualify for elevated Canadian grocery categories.
  *Source: Cobalt official benefits page and Cardmember Agreement.*
  **Not yet verified — treat as 1x by default.**
- **Chase Freedom Rise rewards rate.** Whether Amazon.com USD purchases
  earn 1.5% cash back on Chase Freedom Rise in 2026. *Source: Chase
  Freedom Rise official product page and pricing terms.* **Not yet
  verified; do not assume 1.5% until confirmed.**
- **Chase Freedom Rise current available credit.** Statement date,
  existing balance, and available credit at the moment of purchase.
  *Source: Chase mobile app / statement.* **User-check required.**
- **Wise (Canada) card use on Amazon.com.** Whether Amazon.com accepts
  the Wise prepaid card for a USD checkout, any Wise conversion fee if
  paid from USD balance, and any card usage limits. *Source: Wise
  official Canada card pricing and card acceptance help.* **Not yet
  verified.**
- **AVS / billing-address friction.** Whether shipping to the Sunnyvale
  address with a Canadian billing address triggers any rejection or
  hold on any of the tested cards. *Source: none; empirical —
  user-observable only.*
- **Applicable tax residency / reporting implications.** None expected
  for an ordinary consumer purchase, but noted only because tax
  treatment is never implied by this document (§3). **No action.**
- **Bank of Canada USD/CAD reference rate on 2026-04-21.** Useful only
  for comparing Amazon's 1.36528 CAD/USD against the day's mid-market
  rate to quantify Amazon's spread. *Source: Bank of Canada Valet API
  or daily exchange-rate page.* **Not yet verified.**

##### Payment option matrix

| # | Option                                                                  | Observable cost                   | Main upside                                                 | Main downside / risk                                                                                   | Status     |
|---|-------------------------------------------------------------------------|-----------------------------------|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|------------|
| 1 | Canadian Amex Cobalt, ACC enabled, pay **CAD 480.86**                   | CAD 480.86 (screenshot)           | Already linked; no re-entry; no AVS friction                | Embedded **CAD 13.00** ACC fee (≈3.79% over Amazon's displayed rate); rewards likely only 1x           | Indicative |
| 2 | Canadian Amex Cobalt, pay in **USD 342.67**                             | USD 342.67 + Amex FX conversion   | Skips Amazon ACC fee; Amex handles the conversion           | Amex Canada foreign-currency commission is **not yet verified**; net CAD cost unknown                  | Indicative |
| 3 | **Chase Freedom Rise**, pay in **USD 342.67**                           | USD 342.67 + possible 1.5% reward | U.S. card, U.S. merchant, USD — cleanest FX path; rewards   | **≈68.5% utilization** of a USD $500 limit if it reports before payment; rewards rate **unverified**   | Indicative |
| 4 | **Wise USD card / balance**, pay in **USD 342.67**                      | USD 342.67 (+ any Wise fee)       | No Chase utilization impact; direct USD spend               | Likely no rewards; weaker purchase protection than a credit card; acceptance on Amazon **unverified**  | Indicative |
| 5 | Cart / shipping optimization before any of the above                    | Depends                           | Remove overnight-ship line (Lifeway Kefir, USD 12.99 ship)  | Items actually needed on arrival day may justify the cost — user call                                  | Operational |

##### Preliminary recommendation

This is a preliminary recommendation and is **not** financial advice. Do
**not** place the order until the unknowns above are resolved for the
relevant option.

1. **Before choosing a card**, run the cart optimization step first:
   - Review whether the overnight shipping on the Lifeway Kefir
     (USD 12.99 delivery) is worth it versus buying kefir locally on
     arrival. Removing it saves ≈USD 13 outright and is the biggest
     single line-item saving visible in the screenshots.
   - Review anything that may have accidentally opted into Subscribe &
     Save for a recurring shipment — useful only for genuine repeat
     items.
2. **Pay in USD, not CAD.** The Amazon Currency Converter total
   explicitly adds **CAD 13.00** ≈ **3.79%** on top of Amazon's own
   displayed rate. Unless Amex Canada's verified foreign-currency
   commission is confirmed to be worse than ≈3.79% of the total, paying
   in USD and letting the card issuer handle the conversion is the
   more honest price to compare.
3. **Between the USD-payment options, the choice is a Chase-utilization
   trade-off:**
   - If Chase Freedom Rise **available credit is comfortably above
     USD 342.67** and Ariel can pay the balance **before the statement
     closes** (and therefore before utilization reports), Chase Freedom
     Rise may be attractive for U.S. credit activity and any confirmed
     rewards. The benefit is meaningful because this is a U.S.-merchant,
     USD purchase on a U.S. card — exactly the pattern that builds a
     useful U.S. credit history.
   - If protecting Chase utilization matters more than the rewards
     (which is consistent with the short-term operating goal in §1.9,
     given the low USD $500 limit), the **Wise USD path** is the
     cleaner option: it preserves Chase utilization entirely, with
     the trade-off of giving up any rewards and the credit-card
     purchase-protection layer.
4. **Do not default to the Canadian Amex Cobalt just because it is
   already linked.** Option 1 (ACC in CAD) is almost certainly worse
   than paying in USD on *some* other card; Option 2 (Amex Cobalt in
   USD) is plausibly competitive but cannot be judged until the Amex
   Canada foreign-currency commission is verified.

##### Decision rule

```
IF  cart has been optimized (overnight-shipping lines reviewed; no
    accidental Subscribe & Save) THEN
    pay_currency = USD                # reject Amazon Currency Converter
    IF  Chase Freedom Rise.available_credit >= USD 342.67 + safety_margin
        AND Ariel will pay the Chase balance before the statement closes
        AND Ariel will NOT carry a balance at the 25.24% purchase APR
    THEN
        use Chase Freedom Rise         # U.S. credit activity, possible rewards
    ELSE
        use Wise USD card / balance    # protect Chase utilization, no debt
ELSE
    fix the cart first, then re-run this rule
```

Hard rules that must hold regardless of which branch wins, per the
research standard in §3 and the safety rules in `docs/README.md`:

- Never carry a Chase balance at 25.24% purchase APR just to earn
  rewards.
- Never present any rewards or FX claim as final until verified against
  the current official source listed in *Unknowns to verify*.
- Never enable Amazon Currency Converter without explicitly comparing
  its embedded fee against the issuer's verified foreign-currency
  commission.

##### Follow-up questions

1. What is Amex Canada's current foreign-currency conversion
   commission on the Cobalt, per the official Cardmember Agreement?
2. Does Amazon.com USD spending earn any elevated Cobalt MR category,
   or is it 1x?
3. Does Chase Freedom Rise earn a documented 1.5% cash back on
   Amazon.com USD spend in 2026?
4. What is Chase Freedom Rise's current available credit, statement
   close date, and existing balance on 2026-04-21?
5. Does Amazon.com accept the Wise (Canada) prepaid card for a USD
   checkout to a Sunnyvale delivery address, and what Wise fees apply
   when paying from a USD Wise balance?
6. Does the Sunnyvale Airbnb host allow package delivery before
   arrival, and do any items need to be delayed to avoid missed
   deliveries?
7. Would removing the overnight Lifeway Kefir line save enough on
   shipping to justify buying kefir locally on arrival?
8. On 2026-04-21, what is the Bank of Canada USD/CAD reference rate,
   and how does it compare to Amazon's displayed 1.36528 CAD/USD?

##### Sources that still need verification

Listed explicitly so they can be checked and cited in a later update
rather than invented here. None of these are cited in this document;
they are open verification items only.

- Amazon.com **Amazon Currency Converter** help / terms pages.
- Amazon.com **accepted payment methods** and **card currency** help
  pages.
- **American Express Canada — Cobalt** benefits and **Cardmember
  Agreement** (foreign-currency conversion commission, Amazon earn
  rate).
- **Chase Freedom Rise** official product page and **pricing and
  terms** (rewards rate, APR, foreign transaction fee).
- **Wise Canada** card fee page and Wise card acceptance help.
- **Bank of Canada** daily exchange rates / **Valet** API (for the
  2026-04-21 USD/CAD reference rate).
- **CFPB** and **FCAC** general credit-utilization guidance, used only
  to frame the Chase-utilization trade-off probabilistically — not as
  a guaranteed credit-score outcome.

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
