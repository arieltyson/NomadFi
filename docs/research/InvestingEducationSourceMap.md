# Investing Education — Phase 8A Source Map

This document records the official sources NomadFi cites in its
Phase 8A investing-education starter, the rationale for which
regions ship today, and what the team explicitly chose not to ship.
It is an operational reference for anyone editing the catalogue —
not marketing copy.

The rule is narrow: every lesson in the shipped catalogue must
cite at least one regulator, investor-protection body, or tax
authority. Fund-company marketing pages, brokerage explainers,
investing blogs, and SEO finance content are out of scope. If the
only available source is a brokerage's own page, the lesson does
not ship.

---

## 1. Scope of Phase 8A

Phase 8A is education only. It teaches concepts and procedural
"what to review next" steps. It does **not**:

- recommend specific funds or accounts,
- present suitability framing ("this is right for you"),
- predict returns,
- track or watchlist any fund,
- pull market data,
- ingest brokerage holdings.

Fund tracking and watchlists are deferred to Phase 8B. Phase 5
(Financial Connections) remains externally blocked on Plaid
Limited Production access and Apple's FinanceKit response and is
unaffected by 8A.

---

## 2. Regions that ship in 8A

### United States

NomadFi cites U.S. federal investor-education and tax-authority
material only.

| Lesson | Primary source | URL |
| --- | --- | --- |
| What an index fund is | Investor.gov / SEC — Mutual Funds and ETFs | <https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-4> |
| ETFs and mutual funds at a high level | Investor.gov / SEC — ETFs | <https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-2> |
| Asset allocation, diversification, time horizon | Investor.gov / SEC — Asset Allocation | <https://www.investor.gov/introduction-investing/getting-started/asset-allocation> |
| Fund fees and expenses | Investor.gov / SEC — Mutual Fund Fees and Expenses | <https://www.investor.gov/introduction-investing/investing-basics/glossary/mutual-fund-fees-and-expenses> |
| IRA basics | IRS — Individual Retirement Arrangements (IRAs) | <https://www.irs.gov/retirement-plans/individual-retirement-arrangements-iras> |

Investor.gov is the SEC's Office of Investor Education and
Advocacy. The IRS landing page is the canonical reference for IRA
contribution limits, deductibility, and the difference between
traditional and Roth accounts.

### Canada

NomadFi cites CIRO (the self-regulatory organization that replaced
IIROC and the MFDA), CIPF (Canadian Investor Protection Fund), and
CRA (Canada Revenue Agency).

| Lesson | Primary source | URL |
| --- | --- | --- |
| Investing fees and costs in Canada | CIRO — Fees and Costs | <https://www.ciro.ca/office-investor/investing-basics/fees-and-costs> |
| Know your rights as an investor | CIRO — Know Your Rights as An Investor | <https://www.ciro.ca/office-investor/investing-basics/know-your-rights-investor> |
| Investor protection through CIPF | CIPF | <https://www.cipf.ca/> |
| TFSA basics at a high level | CRA — The Tax-Free Savings Account | <https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/tax-free-savings-account.html> |
| RRSP basics at a high level | CRA — RRSPs and related plans | <https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/rrsps-related-plans.html> |

CIRO is the recognized self-regulatory organization for investment
dealers in Canada. CIPF coverage details change; the catalogue
lesson links the homepage and instructs the reader to read the
current published coverage summary rather than embedding a number
that could go stale.

---

## 3. Regions deliberately deferred

### Trinidad and Tobago

The Trinidad and Tobago Securities and Exchange Commission (TTSEC)
publishes investor-education material through its Investor
Education Centre, including an introductory "Introduction to
Investing" guide. That material is suitable for a future
"investor-protection" or "complaint pathway" lesson.

What is **not** comparable to the U.S. and Canada catalogues today
is the per-account-type retirement layer. Trinidad and Tobago's
defined-contribution / pension-related rules sit across the Board
of Inland Revenue (BIR), the Central Bank of Trinidad and Tobago
(CBTT), and pension-plan trustees rather than in a single
authoritative landing page that mirrors the IRS IRA page or the
CRA TFSA / RRSP pages. Shipping a TT retirement-account lesson
without that level of primary-source clarity would either:

1. require NomadFi to synthesize across multiple non-canonical
   sources (which violates the standing primary-source rule), or
2. force the lesson to stay so generic that it teaches less than
   simply linking the regulator's homepage.

Neither outcome meets the bar 8A is committing to. TT is therefore
deferred from the shipped catalogue. When a follow-up phase adds
TT, the source-map entry below should be filled in with the
confirmed regulator pages before content ships.

| Lesson area | Required source bar before shipping |
| --- | --- |
| Investor protection / complaints | TTSEC Investor Education Centre page |
| Pension / retirement-account analogues | A single canonical regulator landing page covering contribution / withdrawal rules. Until that exists, defer. |

---

## 4. Editing rules for the catalogue

These are the rules `InvestingEducationCatalog.swift` and the
focused tests pin. Any edit that violates them must update both
the catalogue and the test that enforces the rule.

1. **Primary sources only.** Investor.gov, SEC, IRS, CIRO, CIPF,
   CRA, and equivalent regulators / tax authorities. No fund
   companies, brokerages, blogs, Reddit, Wikipedia, or SEO
   finance pages.
2. **Every lesson cites at least one source.** Lessons with no
   sources are filtered out by `InvestingEducationCatalog.isValid`
   so they cannot reach the UI.
3. **Procedural language only.** "What it is / why it matters /
   what to review next." Never "you should buy", "best fund",
   "this is right for you", "you'll earn", or any outcome /
   suitability claim.
4. **No predicted returns.** No example portfolios with future
   numbers. No "if you had invested" charts.
5. **Region honesty.** Region display names are absolute
   ("Canada", not "your country"). Regions the catalogue does not
   cover are silently omitted from the surface — never replaced
   with a U.S. fallback.
6. **Cross-border escalation.** Lessons whose subject interacts
   with residency or tax treaties (asset allocation, IRA basics,
   TFSA, RRSP) carry an escalation note pointing the reader to a
   registered professional.

The standing footer on the surface — "Education only. Not
investment advice. Not a substitute for a registered investment
professional. NomadFi does not recommend specific funds or
accounts." — is non-removable.

---

## 5. Refresh discipline

Regulator pages change. The catalogue links the official pages
rather than embedding numbers, but the reader-prompts can still
drift. The team should re-walk every URL in this document at the
start of each calendar quarter and confirm:

- the URL still resolves,
- the page still describes the same concept,
- the cited summary is still accurate,
- no superseding regulator page has replaced it.

If a URL has moved, update both `InvestingEducationCatalog.swift`
and this document in the same change.
