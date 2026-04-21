# NomadFi Docs

Source governance and research validation for NomadFi. This document is the
operating standard that any recommendation-generating code, analysis, or agent
must follow before turning a claim into user-facing advice.

This file is **public-safe documentation**. It contains no account numbers,
government IDs, balances, addresses, employer, or school details.

---

## Purpose

NomadFi makes cross-border financial recommendations — card routing, FX-waste
reduction, rewards, credit-building, and tax-aware planning — for international
students, temporary residents, interns, and other cross-border earners.

Those recommendations are only as trustworthy as their sources. This document
defines:

1. The evidence hierarchy NomadFi uses to validate financial claims.
2. Which organizations, regulators, and publications are authoritative for
   each financial domain.
3. Which sources must **not** be treated as authoritative.
4. How to label user-provided facts vs. verified product terms vs. inferred
   strategy.
5. Freshness and re-verification rules for volatile data.
6. A citation standard for recommendation work.
7. Known implementation gaps in the current codebase where source provenance
   is missing.
8. Hard safety rules the product must never violate.

---

## Privacy Boundary

- This file (`docs/README.md`) is public-safe.
- [`docs/ARIEL.md`](./ARIEL.md) is a **private personal testbed baseline**. It
  contains sensitive cross-border personal finance context and should **not**
  be pushed to a public remote without an explicit privacy review.
- Public documentation must not duplicate `ARIEL.md` content — reference it by
  path, do not copy facts from it.

---

## Evidence Hierarchy

Every claim used in a recommendation must be mapped to a tier below. Higher
tiers override lower tiers when they disagree.

1. **Official primary sources.** Issuer/bank product pages, cardmember
   agreements, fee disclosures, central-bank datasets, regulator publications,
   and government tax/residency guidance.
2. **Official secondary sources.** Regulator-published consumer guides,
   deposit-insurance corporation publications, and government statistical
   agencies interpreting primary rules.
3. **Institutional research.** Central-bank working papers, IMF/World
   Bank/BIS/OECD datasets and analyses, reputable industry research with
   transparent methodology and disclosed conflicts.
4. **Peer-reviewed academic research.** Behavioral, demographic, social-impact,
   and market-structure claims where applicable.
5. **Prototype / indicative data sources.** Free/open public APIs, aggregator
   sites, commercial comparators. Usable for non-critical display only and
   **must be labeled as indicative**.
6. **Non-authoritative sources.** Blogs, affiliate card-comparison sites,
   Reddit, TikTok, YouTube, SEO "best cards" pages. Usable for **discovery
   of questions only**, never as evidence.

When tiers conflict, the higher tier wins, and the lower-tier source is
demoted to context or removed.

---

## Source Categories

### Product Terms and Issuer Disclosures

Authoritative for: APR, annual fees, foreign-transaction fees, rewards earn
and redemption rates, eligibility, credit limits, cardholder insurance, and
account terms.

- **Chase** — official product pages, pricing and terms, cardmember agreements,
  account disclosures.
- **American Express (Canada)** — official card pages, cardmember agreements,
  Membership Rewards terms, insurance certificates, and upgrade-offer terms.
- **CIBC** — official credit-card pages, card agreements, fee disclosures, and
  banking account terms.
- **Wise** — official pricing, card fee, transfer fee, supported-currency, and
  account terms pages.
- **Wealthsimple** — official account, TFSA, card, managed-investing,
  self-directed investing, and fee pages.
- **Unit Trust Corporation (Trinidad and Tobago)** — official product and
  account documentation.

Rule: if a third-party comparator disagrees with the issuer's own current
disclosure, the issuer wins.

### Credit and Consumer Protection

Authoritative for: credit-reporting rights, credit-card consumer protections,
dispute processes, and general credit-building principles.

- **United States**
  - **CFPB** — credit reports, credit scores, credit-card terms, consumer
    protection.
  - **FTC** — consumer protection, identity-theft guidance.
  - **AnnualCreditReport.com** — the official U.S. free credit-report portal.
  - **FICO**, **VantageScore** — score-model authorities (general principles
    only; exact model internals are proprietary).
  - **Experian**, **Equifax (US)**, **TransUnion (US)** — bureau policies and
    dispute procedures.
  - **FDIC** — deposit insurance and bank safety.
  - **OCC / HelpWithMyBank** — national-bank consumer assistance.
- **Canada**
  - **FCAC** — credit reports, credit scores, banking rights, consumer
    protection.
  - **Equifax Canada**, **TransUnion Canada** — Canadian bureau policies and
    disputes.
  - **Provincial consumer protection agencies** — provincial banking/credit
    rights.
  - **OSFI** — federally regulated financial institutions.
  - **CDIC** — Canadian deposit insurance.

Rules:

- Do not overstate exact scoring effects — scoring models are proprietary.
- Always distinguish general credit principles (utilization, payment history,
  account age, inquiries, mix) from guaranteed score outcomes.
- Discuss score factors **probabilistically**, never as deterministic formulas.
- **Never recommend paying interest to build credit.**

### FX, Rates, and Market Data

Priority order for any FX rate used in a recommendation:

1. **Official central-bank datasets.**
   - Bank of Canada exchange rates / Valet API.
   - Federal Reserve H.10 foreign exchange rates.
   - Central Bank of Trinidad and Tobago daily exchange rates.
2. **Official issuer/network calculators** (when the recommendation depends
   on how a specific network actually converts):
   - Visa exchange rate calculator.
   - Mastercard currency conversion calculator.
   - Wise pricing and live quote pages (for Wise-specific transfer/card
     pricing only).
3. **Institutional datasets for research context.**
   - IMF, World Bank, BIS, OECD, FRED.
4. **Commercial / open APIs.**
   - Permitted for prototype UX, non-critical display, and demos **only if
     clearly labeled as indicative and not authoritative**.
   - Must not silently become the source of truth for high-stakes advice.

Rule: a card-routing or "real cost" recommendation that materially affects the
user's money must cite a Tier-1 or Tier-2 source, not a Tier-4 API.

### Tax and Residency

Authoritative sources only, and **always** accompanied by a clear "not
professional advice" label.

- **United States**
  - IRS Publication 519 (U.S. Tax Guide for Aliens).
  - IRS guidance for J-1 visa holders.
  - IRS Form 1040-NR and Form 8843 instructions.
  - Applicable income-tax treaty texts where treaty treatment matters.
- **Canada**
  - CRA guidance for international students.
  - CRA tax-residency-status determination.
  - CRA TFSA, RRSP, and related registered-account rules.
- **Trinidad and Tobago**
  - Ministry of Finance.
  - Board of Inland Revenue.
  - Financial Intelligence Unit of Trinidad and Tobago (FIUTT) for AML/CFT
    context.

Rules:

- **Do not infer final tax residency without user confirmation and a
  source-backed decision flow.**
- Do not recommend tax moves without telling the user which assumptions must
  be verified with the relevant authority or a qualified professional.
- Label all tax information as planning context, **not professional advice**.
- Do not present immigration-adjacent guidance (e.g., work authorization
  implications for J-1 or study-permit holders) as legal advice.

### Investing and Brokerage Protection

Authoritative for: investor protection, brokerage regulation, advisor conduct,
and insured-account coverage.

- **United States** — SEC, FINRA, SIPC.
- **Canada** — CSA, OSC, BCSC and other provincial securities regulators,
  CIRO, CIPF.
- **Trinidad and Tobago** — TTSEC (Trinidad and Tobago Securities and Exchange
  Commission).

Rule: eligibility, account type, and protection-coverage statements must come
from the regulator or the regulated institution's current disclosures, not
from marketing content.

### Trinidad and Tobago Sources

Consolidated for convenience — authoritative for T&T-side claims:

- **Central Bank of Trinidad and Tobago** — exchange rates, financial
  stability, list of regulated financial institutions.
- **Trinidad and Tobago Securities and Exchange Commission (TTSEC)** —
  securities and investor protection.
- **Ministry of Finance** and **Board of Inland Revenue** — tax and fiscal
  rules.
- **Financial Intelligence Unit of Trinidad and Tobago (FIUTT)** — AML/CFT
  and financial compliance context.

### Academic and Market Research

Use for: behavioral claims, demographic claims, social-impact claims, and
market-structure claims.

- **Peer-reviewed journals** located via DOI, Google Scholar, or institutional
  library databases — the highest evidence tier for behavioral and
  market-structure claims.
- **Central-bank research papers** and regulator reports — treat as
  institutional research, not peer-reviewed authority.
- **NBER** and **SSRN** working papers — label explicitly as **working papers**,
  not peer-reviewed final authority.
- **Government statistical agencies** and regulator datasets — for market
  context.
- **Reputable industry research** — only when methodology is transparent and
  conflicts of interest are disclosed.

Non-authoritative, **not usable as evidence**:

- Personal-finance blogs.
- Affiliate credit-card comparison sites.
- Reddit, TikTok, YouTube, and SEO "best cards" pages.
- Unbylined aggregator pages without methodology.

These channels are allowed only for **discovery of questions to then validate
against authoritative sources**. Affiliate compensation is treated as a
conflict of interest and must be noted if such a source is referenced at all.

---

## Source Freshness Rules

Cached sources go stale. Apply these re-verification windows.

| Data type                                         | Verify when / how often                                   |
| ------------------------------------------------- | --------------------------------------------------------- |
| Live FX / market rates                            | Verify at time of recommendation.                         |
| Card APRs, annual fees, foreign-transaction fees, rewards | Verify before each recommendation session, or at least monthly if cached. |
| Tax and residency rules                           | Verify against current tax-year official guidance.        |
| Credit-score and credit-reporting guidance        | Review at least quarterly, and whenever a bureau or regulator publishes new guidance. |
| Deposit-insurance coverage limits                 | Verify annually and whenever the insurer announces a change. |
| Academic research                                 | Cite the original publication date; do not treat an old study as a current market claim. |
| Issuer cardmember agreements                      | Re-fetch whenever the issuer posts a "terms updated" notice. |

If a cached value is outside its window, the UI must either re-fetch or
**label it as stale** before it is used in a recommendation.

---

## Citation Standard

Every claim used in a recommendation must be expressible in this shape. The
current codebase does not yet store provenance in this form — see the
"Current Implementation Gap" section.

- **Claim:** _The one-sentence factual claim being made._
- **Source:** _Publisher / institution name._
- **Source type:** _Primary issuer disclosure, central-bank dataset,
  regulator guidance, peer-reviewed paper, institutional research, prototype
  API, etc._
- **URL:** _Direct URL to the primary source page or document._
- **Published / updated date:** _As stated by the source._
- **Accessed date:** _When NomadFi fetched or last verified it._
- **Jurisdiction:** _US, CA, TT, or cross-border._
- **Confidence:** _`verified-primary`, `verified-secondary`, `institutional`,
  `peer-reviewed`, `indicative`, or `unverified`._
- **Notes / limitations:** _Methodology caveats, scope limits, or known
  staleness._

Additional rules:

- **Never fabricate citations.** A claim without a real citable source must
  be presented as an inference, not a fact.
- User-provided facts are not citations; they must be labeled as
  `user-provided` and, where they affect recommendations, confirmed against a
  primary source.

---

## Current Implementation Gap

This section is intentionally specific so a future coding agent can close the
gaps without guessing.

- **Live FX service.**
  [`LiveExchangeRateService`](../NomadFi/NomadFi/Core/Services/Live/LiveExchangeRateService.swift)
  currently calls `https://open.er-api.com/v6/latest/`, a free public
  exchange-rate API. Per the evidence hierarchy, this is a **Tier-5 prototype
  source**. It is acceptable for prototype display only if the UI labels the
  value as **indicative**. Any production card-routing or FX-waste
  recommendation must either (a) validate against a Tier-1 source (Bank of
  Canada / Valet API, Federal Reserve H.10, Central Bank of Trinidad and
  Tobago) or (b) persist source provenance and freshness metadata alongside
  the rate so the UI can honestly label it.
- **Account fee inputs.** Fields such as
  `Account.foreignTransactionFeePercent` used by
  [`InsightEngine`](../NomadFi/NomadFi/Core/Services/InsightEngine.swift),
  [`LedgerViewModel`](../NomadFi/NomadFi/Features/Ledger/LedgerViewModel.swift),
  and
  [`ActiveCardIntent`](../NomadFi/NomadFi/Features/Intents/ActiveCardIntent.swift)
  are currently plain numeric inputs. They need source provenance (issuer page
  URL, `published/updated date`, `accessed date`) before any output derived
  from them can be treated as a verified recommendation rather than a
  scenario-style estimate.
- **Provenance model.** There is no `Source` / `Citation` model or companion
  freshness field on recommendation-facing data. Until one exists, any
  cross-border recommendation must be rendered with an explicit "indicative
  — verify with issuer" affordance.
- **Governance utility.**
  [`DataGovernancePolicy`](../NomadFi/NomadFi/Core/Utilities/DataGovernancePolicy.swift)
  is the natural home for encoding these freshness windows and the
  indicative/authoritative distinction.

None of these gaps are fixed by this document — they are surfaced here so the
next code change can be scoped honestly.

---

## Recommendation Safety Rules

These are hard rules. A recommendation that violates any of them must be
blocked before it reaches the user.

- **Never recommend carrying a credit-card balance** to earn rewards, build
  credit, or signal anything to a bureau.
- **Never recommend cash advances** for investing, rewards, arbitrage, or any
  other purpose.
- **Never present product eligibility as guaranteed.** Final eligibility is
  always the issuer's decision under current underwriting.
- **Never present tax or immigration conclusions as professional advice.**
  Always direct users to the relevant authority or a qualified professional
  for consequential decisions.
- **Always separate** user-provided facts, verified product terms, and
  inferred strategy in the UI and in generated recommendations.
- **Always label** stale, uncertain, or Tier-5 indicative data — never let it
  appear to the user as verified.
- **Never encourage** behavior that trades a small rewards yield for a larger
  interest, FX, or fee cost.

---

## Relationship to ARIEL.md

[`ARIEL.md`](./ARIEL.md) is a **private testbed baseline** capturing a real
cross-border financial life used to shape and evaluate NomadFi's behavior.

- `ARIEL.md` is the primary user-provided fact set for the testbed. Its
  contents enter recommendations labeled as `user-provided` and must be
  reconciled against authoritative sources per this document before being
  treated as `verified`.
- `ARIEL.md` must not be pushed to a public remote without a privacy review.
- This `README.md` must not duplicate `ARIEL.md`'s sensitive contents.
  Reference it by path when needed; do not copy it.
