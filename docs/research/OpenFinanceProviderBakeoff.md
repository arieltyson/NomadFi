# Open-Finance Provider Bakeoff — Phase 5D Research Memo

Decision-grade research on whether NomadFi should pilot an external
open-finance provider beyond Apple FinanceKit + manual + CSV, and if
so, which one first. Written to be used, not skimmed.

Scope of this memo is **research only**. Phase 5D ships no provider
SDK, no Plaid client, no Akoya client, no MX client, no
Finicity/Mastercard client, and no direct FDX client. The next slice
that adds vendor code is Phase 5E, and only after this memo forces a
concrete decision.

---

## 0. TL;DR

- **First technical evaluation candidate:** Plaid (US-focused,
  free sandbox, public pricing, self-serve).
- **First privacy / API-first comparison candidate:** Akoya (API-only
  positioning, free sandbox, enterprise-oriented onboarding).
- **Reserve candidates (for a later enterprise-style comparison):**
  MX, Mastercard/Finicity.
- **Strategic reference path (not a near-term implementation
  candidate):** direct FDX / FAPI per-bank integration.
- **Branch: "no provider clears the bar yet."** Real and honest.
  Concrete exit criteria are listed in §7.
- **Immediate next action after Phase 5D:** run a small, time-boxed
  Plaid **sandbox** proof (≤ 1 week) against NomadFi's Decision
  Assistant needs (Transactions + Auth + Balance) — and only if that
  clears the bar, spin up a matching Akoya sandbox comparison. Do
  not sign a paid contract with any provider in Phase 5D.

Ranking rationale is in §6; evidence scorecard in §5; methodology in
§2; known unknowns in §8.

---

## 1. Framing

NomadFi's mission ([`docs/MISSION.md`](../MISSION.md)) is a
**cross-border financial decision assistant for international
students, temporary residents, interns, immigrants, and other
multi-country earners**. The product is a Decision Assistant first,
not a general-purpose PFM. The target jurisdictions are:

- United States
- Canada
- Trinidad and Tobago (home-country footprint for our target
  archetype)
- cross-border reality across all of the above

This framing shifts the bakeoff away from the usual "best US PFM
aggregator" debate. A provider that wins on US coverage alone is
necessary but not sufficient; a provider that is strong on privacy
and authorization UX but weak on Canadian coverage is also not a
clean answer.

FinanceKit fills part of this gap (see
[`FinanceKitFeasibility.md`](./FinanceKitFeasibility.md) for the full
dossier). It is free, on-device, privacy-strong, and entitlement-
gated; coverage is Apple Card / Apple Cash / Apple Savings in the US
and a selected set of UK open-banking institutions. It is not
sufficient on its own for NomadFi's cross-border target: no Chase,
no CIBC, no Trinidad-and-Tobago institution, no generic US bank. The
question this memo asks is whether a third-party provider is the
right way to close that gap now, or whether NomadFi should stay on
FinanceKit + manual + CSV until more evidence exists.

---

## 2. Methodology

### 2.1 Source rules

**Allowed sources**

- Official Apple documentation (developer.apple.com).
- Official regulator / government sources:
  - CFPB for the US (consumerfinance.gov).
  - Department of Finance Canada and FCAC for Canada
    (canada.ca / fcac-acfc.gc.ca).
  - Central Bank of Trinidad and Tobago (central-bank.org.tt) for TT.
- Official standards-body sources:
  - FDX (financialdataexchange.org).
  - OpenID Foundation's FAPI working group material (openid.net).
- Official provider/vendor documentation hosted on each vendor's own
  primary domain:
  - plaid.com / plaid.com/docs
  - akoya.com / developer.akoya.com
  - mx.com / docs.mx.com
  - mastercard.com / developer.mastercard.com
  - finicity.com

**Excluded sources**

- Consultant blogs, Medium posts, agency comparison articles, and
  "best fintech aggregator" listicles. Intentionally unread.
- Reddit / Hacker News / fintech Slack threads.
- Non-primary journalism that summarizes vendor claims without a
  linkable primary source.
- AI-generated market reports.

### 2.2 How vendor claims are treated

Claims that appear only on a vendor's own site or documentation
(institution counts, "best-in-class privacy," "100 % OAuth at the top
banks," etc.) are labelled **vendor-reported** wherever they appear
below. They are *not* promoted into facts unless a regulator,
standards body, or third-party primary source independently supports
them.

### 2.3 Where evidence is strong vs. weak

- **Strong (primary-source, verifiable today):** official API shapes,
  sandbox availability, presence or absence of public pricing,
  product names, framework availability on specific platforms,
  regulator text (CFPB 1033, Consumer-Driven Banking Act of Canada).
- **Weak (vendor-reported, not independently validated):** specific
  institution counts, end-user OAuth conversion rates, "market
  leadership" claims, "fastest sync" / "widest coverage" claims,
  pricing below the first public rung.
- **Unknown from public sources:** long-term unit economics for a
  specific startup use case, real production reliability, concrete
  % of NomadFi's target users' institutions that are actually
  OAuth-first with a given provider, the rate at which sandbox
  fidelity matches production behavior.

### 2.4 What is not knowable from public sources alone

- Whether a given provider will actually approve NomadFi for
  production access, and on what commercial terms.
- Whether sandbox data fidelity matches production behavior for
  NomadFi's specific use cases.
- Real transaction enrichment accuracy against NomadFi's deterministic
  `MerchantNormalizer` / `RecurringChargeDetector`.
- Whether a vendor's Canadian coverage matches NomadFi's
  international-student user institutions specifically (RBC, CIBC,
  TD, Scotia, BMO, Tangerine, Simplii, etc.).

This memo does **not** attempt to answer those questions from
documents alone. Resolving them is exactly what a Phase 5E sandbox
pilot is for.

### 2.5 Extensibility

This memo is structured so a follow-up contributor can refresh
individual cells without redoing the whole thing: §4 candidate
profiles, §5 scorecard, and §8 unknowns are additive and each has a
citation tag per claim.

---

## 3. The regulatory frame (primary sources)

### 3.1 United States — CFPB 1033

The Consumer Financial Protection Bureau finalized the Personal
Financial Data Rights rule (12 CFR Part 1033) in October 2024.
Relevant anchors for a third-party data recipient are already cited
inline in [`../TIMELINE.md`](../TIMELINE.md); the core requirements
are:

- Covered data includes balances and transactions; up to 24 months
  of transaction history is in scope. (§ 1033.211.)
- Authorization must be explicit and informed. (§ 1033.401.)
- Collection / use / retention must be limited to what is reasonably
  necessary. (§ 1033.421.)
- Use of an aggregator must be disclosed and the aggregator must be
  identified. (§ 1033.431.)
- Authorization and aggregator certifications must be retained.
  (§ 1033.441.)

As of April 2026, the rule has been subject to legal challenge and
partial stays, but the regulatory shape is the one NomadFi must
design to. Any chosen provider must make 1033-compliant consent,
disclosure, minimization, revocation, and retention achievable on
the NomadFi side — not impossible.

### 3.2 Canada — Consumer-Driven Banking Act

Parliament passed the Consumer-Driven Banking Act in 2024 (per the
Department of Finance Canada). The Financial Consumer Agency of
Canada (FCAC) is the designated supervisor. The framework is in the
implementation phase; as of this memo:

- There is no operational consumer-driven-banking technical regime
  that a developer can call a "Canadian CFPB 1033" endpoint against.
- Canadian coverage on any third-party aggregator is therefore
  contingent on bilateral partnerships the aggregator has with
  Canadian FIs rather than on a unified regulator-mandated API.
- NomadFi's Canadian coverage strategy must assume uneven
  institution-by-institution support until the regime operationalizes.

### 3.3 Trinidad and Tobago

The Central Bank of Trinidad and Tobago has not published an
operational open-banking / consumer-financial-data-rights regime
comparable to CFPB 1033 or Canada's Consumer-Driven Banking Act. No
evaluated provider documents TT institution coverage. NomadFi must
therefore not imply coverage for TT accounts through any third-party
aggregator in this slice; TT stays on manual + CSV.

### 3.4 Standards — FDX / FAPI

FDX (Financial Data Exchange) is the royalty-free industry standard
referenced as the architectural target in NomadFi's Phase 5 planning.
FAPI (OpenID Foundation's Financial-grade API) is the security
profile FDX aligns with. Both matter for evaluating a provider's
architecture, but neither is a consumer-deployable integration path
for a small app: FDX compliance describes a bilateral bank-by-bank
integration model that a startup cannot feasibly ship as the sole
data strategy.

---

## 4. Candidate profiles

Each candidate below lists (a) what the vendor's own primary docs say
it does, (b) where evidence is weak, and (c) the candidate's
acceptance for NomadFi specifically.

### 4.1 Plaid

Primary source anchors:

- [Plaid Docs — Transactions](https://plaid.com/docs/transactions/)
- [Transactions API](https://plaid.com/docs/api/products/transactions/)
- [Balance](https://plaid.com/docs/api/products/balance/)
- [Auth](https://plaid.com/docs/api/products/auth/)
- [Institutions](https://plaid.com/docs/institutions/)
- [OAuth in Link](https://plaid.com/docs/link/oauth/)
- [Pricing](https://plaid.com/pricing/)
- [Billing mechanics](https://plaid.com/docs/account/billing/)
- [Plaid in Canada](https://plaid.com/en-ca/)
- [Webhooks](https://plaid.com/docs/api/webhooks/)

What the vendor's own docs say:

- REST + Plaid Link client (Plaid Link is the consent UI layer).
- Products NomadFi actually needs: **Transactions**, **Auth**,
  **Balance**. Investments and Liabilities are adjacencies, not core.
- Transactions history up to 24 months, with webhooks for
  incremental sync (`SYNC_UPDATES_AVAILABLE`), consistent with
  CFPB 1033's 24-month window.
- OAuth is supported at many large US institutions (vendor-reported
  counts of "thousands" — not promoted to fact here).
- Canadian coverage is marketed on a dedicated regional page; the
  institution list is vendor-reported.
- Sandbox is publicly self-serve (developer account, sandbox keys).
- Pricing has a publicly visible first rung, which is unusually
  transparent for this market — Plaid publishes an always-free
  development tier and production rates per product per connected
  account or per API call on its public pricing page.

Weak / vendor-reported:

- Specific institution counts, end-user OAuth conversion, and
  Canadian FI coverage are vendor-reported. Sandbox fidelity vs.
  production is vendor-reported.

Acceptance for NomadFi:

- ✅ US coverage for the Decision Assistant use case is the strongest
  among candidates, per vendor-reported evidence + self-serve
  sandbox.
- ⚠️ Canadian coverage is marketed but must be validated in a
  sandbox pilot with NomadFi's target-user institutions.
- ✅ Consent UX (Plaid Link) is well-documented and supports the
  explicit-authorization / disclosure / revocation semantics NomadFi
  needs for 1033-aligned design.
- ⚠️ Pricing can become a pre-revenue burden fast; NomadFi must
  model per-user cost *before* committing.

### 4.2 Akoya

Primary source anchors:

- [Akoya overview](https://akoya.com/)
- [Developer portal](https://developer.akoya.com/)
- [Fintechs](https://akoya.com/fintechs)
- [Products overview](https://akoya.com/products-overview)
- [Balances](https://akoya.com/products/balances)
- [Investments](https://akoya.com/products/investments)
- [Pricing](https://akoya.com/pricing)

What the vendor's own docs say:

- API-only, no credential-sharing (the "Data Access Network" model).
- Positioned as a direct-bank-API intermediary; emphasizes
  permissioned-API architecture aligned with FDX.
- Free sandbox for developers.
- Products cover accounts, balances, transactions, and investments.

Weak / vendor-reported:

- Institution counts and concrete OAuth conversion are vendor-
  reported. Pricing below the first rung is not transparent on the
  public pricing page (contact-sales beyond sandbox).
- Canadian institution coverage is not documented on the public
  product pages reviewed for this memo.

Acceptance for NomadFi:

- ✅ Strong architectural fit with FDX / CFPB 1033 principles
  (vendor-reported but consistent with their public product framing).
- ✅ Free sandbox makes a head-to-head comparison feasible alongside
  Plaid without paid commitment.
- ⚠️ Production onboarding appears less startup-self-serve than Plaid
  — public materials point at enterprise-style sales contact.
- ⚠️ Canadian and TT coverage are not demonstrated from public
  sources; NomadFi must not assume them.

### 4.3 MX

Primary source anchors:

- [MX Open Finance](https://www.mx.com/open-finance/)
- [Use cases](https://www.mx.com/use-cases/open-finance/)
- [Platform APIs](https://docs.mx.com/)

What the vendor's own docs say:

- "MX Platform API" + "Open Finance API" product split.
- Strong data-cleansing / enhancement story (vendor-reported — their
  whole public positioning centers on this).
- FDX-aligned framing.
- Sandbox access exists but access is less publicly self-serve than
  Plaid's.

Weak / vendor-reported:

- Public pricing is not transparent; MX markets to enterprise.
- Institution counts and exact OAuth-first ratios are vendor-reported.

Acceptance for NomadFi:

- ⚠️ MX's public stance leans enterprise. Not the right first
  evaluation candidate for a pre-revenue, startup-stage NomadFi.
- ✅ Reserve for a second-round comparison if Plaid + Akoya both
  fail the bar.

### 4.4 Mastercard / Finicity

Primary source anchors:

- [Mastercard Open Banking](https://www.mastercard.com/us/en/business/open-banking.html)
- [Mastercard-Finicity acquisition press release](https://www.mastercard.com/news/press/press-releases/2020/june/mastercard-to-acquire-finicity-to-advance-open-banking-strategy/)
- [Mastercard Open Finance developer](https://developer.mastercard.com/product/open-banking-us)
- [Finicity developer docs](https://developer.finicity.com/)

What the vendor's own docs say:

- Mastercard completed the Finicity acquisition in 2020; Finicity's
  capabilities are being rolled up into Mastercard's "Open Banking"
  and "Open Finance" product families.
- Products include account owner verification, balance check,
  transaction retrieval, and cash-flow analysis.
- Developer portal requires a developer account; sandbox is
  available; commercial access requires a Mastercard Open Banking
  agreement.
- FDX participation is publicly documented.

Weak / vendor-reported:

- Public pricing is not transparent; production access requires
  commercial-contact workflow.
- Coverage numbers and conversion rates are vendor-reported.

Acceptance for NomadFi:

- ⚠️ Finicity-via-Mastercard is institutionally strong but
  startup-unfriendly for a pre-revenue product. Reserve for later.
- ✅ Architectural fit with FDX is public and defensible.

### 4.5 Direct FDX / FAPI (per-bank)

Primary source anchors:

- [FDX mission](https://financialdataexchange.org/FDX/FDX/About/About-FDX.aspx)
- [FDX 6.4 release announcement](https://financialdataexchange.org/FDX/FDX/News/Announcements/FDX_Announces_Spring_2025_API_Release_6_4.aspx)
- [OpenID FAPI](https://openid.net/wg/fapi/)

What the standards say:

- FDX is royalty-free, vendor-neutral, and endorsed by the major
  US institutions publicly.
- FAPI (OpenID) is the security profile FDX aligns with.
- A direct FDX integration means calling each bank's FDX endpoint
  with each bank's OAuth client credentials.

Acceptance for NomadFi:

- ❌ Not a practical near-term implementation target for a
  pre-revenue startup. Bilateral bank-by-bank onboarding dominates.
- ✅ Architectural reference path. NomadFi's provider seam should
  stay compatible with FDX-shaped data, so that a future adapter
  (a real provider that wraps FDX calls, or a direct FDX client for
  one or two strategically-valuable banks) can be added without
  restructuring the reconciler or domain model. This is already the
  case in-code.
- 📎 Useful as a standards anchor to score the real candidates
  against — see the scorecard in §5.

---

## 5. Scorecard

Legend for the cells:

- ✅ = NomadFi-relevant evidence is strong and defensible from
  primary sources.
- ⚠️ = evidence is partial, vendor-reported only, or conditional on
  sandbox validation.
- ❌ = evidence is missing or actively contraindicates NomadFi.

Every cell must be interpretable without vendor marketing claims.

### 5.1 Target-market coverage

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| United States — breadth | ✅ vendor-reported large; self-serve sandbox | ⚠️ vendor-reported; enterprise onboarding | ⚠️ vendor-reported; enterprise onboarding | ⚠️ vendor-reported via Mastercard portal | ⚠️ bank-by-bank bilateral |
| United States — OAuth at top FIs | ⚠️ vendor-reported | ✅ API-only positioning is consistent with OAuth-first | ⚠️ vendor-reported | ⚠️ vendor-reported | ✅ FAPI-aligned by definition |
| Canada — any operational coverage | ⚠️ vendor-reported; must be sandbox-validated | ❌ not documented publicly | ❌ not documented publicly | ❌ not documented publicly | ❌ no operational regulatory API |
| Trinidad and Tobago | ❌ no evidence of coverage | ❌ no evidence of coverage | ❌ no evidence of coverage | ❌ no evidence of coverage | ❌ no regime |

Implication: for NomadFi's cross-border target, no single third-party
provider solves Canada + TT today. Plaid is the only candidate that
even markets Canadian coverage. TT stays on manual + CSV regardless.

### 5.2 Account-type coverage (NomadFi-relevant)

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Depository accounts (checking / savings) | ✅ | ✅ | ✅ | ✅ | ✅ where bank exposes FDX |
| Credit cards | ✅ via Transactions / Liabilities | ✅ | ✅ | ✅ | ✅ where bank exposes FDX |
| Transactions (NomadFi's primary need) | ✅ REST + sync webhooks | ✅ permissioned API | ✅ | ✅ | ✅ bank-dependent |
| Balances on-demand | ✅ | ✅ | ✅ | ✅ | ✅ bank-dependent |
| Investments (NomadFi secondary) | ✅ optional | ✅ optional | ⚠️ varies | ✅ optional | ✅ bank-dependent |

Implication: every serious candidate covers the data classes
NomadFi actually needs. Differentiation is not in "what's available"
but in consent UX, cost, onboarding friction, and coverage *in the
user's actual institutions*.

### 5.3 API / OAuth / permission model quality

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| REST API + sandbox + SDKs | ✅ | ✅ | ✅ | ✅ | ❌ |
| OAuth-first posture (primary-source) | ⚠️ product path rather than architectural guarantee | ✅ API-only, no credential sharing | ⚠️ mixed | ⚠️ mixed | ✅ by design |
| Consent UX primitive shipped by vendor | ✅ Plaid Link | ⚠️ institution-portal handoffs | ⚠️ vendor-reported | ⚠️ vendor-reported | ❌ per-bank custom |
| Webhooks / incremental sync | ✅ `TRANSACTIONS` webhooks + `/sync` | ✅ vendor-reported | ✅ vendor-reported | ✅ vendor-reported | ⚠️ bank-dependent |

### 5.4 CFPB-1033 + FDX alignment (architecture)

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Explicit authorization, per-product | ✅ | ✅ | ✅ | ✅ | ✅ |
| Disclosed aggregator use (§ 1033.431 posture) | ✅ disclosable via Plaid Link copy | ✅ positioning aligns | ✅ documented | ✅ documented | ✅ trivially — there is no aggregator |
| Minimum-necessary data | ⚠️ NomadFi-controlled — must scope products narrowly | ⚠️ NomadFi-controlled | ⚠️ NomadFi-controlled | ⚠️ NomadFi-controlled | ⚠️ NomadFi-controlled |
| Revocation UX | ✅ documented | ✅ documented | ✅ documented | ✅ documented | ✅ per-bank |
| Retention of authorization evidence | ⚠️ NomadFi responsibility | ⚠️ NomadFi responsibility | ⚠️ NomadFi responsibility | ⚠️ NomadFi responsibility | ⚠️ NomadFi responsibility |

Implication: every candidate makes 1033-aligned design *possible*. The
NomadFi side (scoping data, keeping retention limited, storing
authorization evidence) does the actual compliance work.

### 5.5 Developer ergonomics

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Self-serve developer account | ✅ | ✅ | ⚠️ | ⚠️ | ❌ |
| Free sandbox with realistic fixtures | ✅ | ✅ | ⚠️ | ⚠️ | ❌ |
| Public docs quality | ✅ | ✅ | ✅ | ✅ | ✅ |
| Time-to-first-API-call (< 1 hour from account creation) | ✅ | ✅ | ⚠️ | ⚠️ | ❌ |

### 5.6 Production onboarding friction

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Self-serve production onramp (no sales call) | ✅ (for first paid tier) | ⚠️ enterprise onboarding path | ⚠️ enterprise | ⚠️ enterprise | ❌ |
| KYC / vetting burden before first production call | ⚠️ (standard startup vetting) | ⚠️ (enterprise-style) | ⚠️ | ⚠️ | ❌ |

### 5.7 Privacy / security posture (primary-source)

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Publishes SOC 2 posture | ✅ | ✅ | ✅ | ✅ | ❌ |
| Data-minimization scoping supported at the API level | ⚠️ via product selection | ✅ API-only posture | ⚠️ product selection | ⚠️ product selection | ✅ trivially |
| No credential sharing with end-users (OAuth-first) | ⚠️ institution-dependent | ✅ | ⚠️ institution-dependent | ⚠️ institution-dependent | ✅ |

### 5.8 Pricing model + unit-economics risk

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Public pricing page with concrete first rung | ✅ | ⚠️ sandbox free; production pricing requires contact | ❌ | ❌ | ❌ |
| Pay-as-you-go for low volume | ✅ per vendor page | ⚠️ | ❌ | ❌ | — |
| Per-connected-user risk of runaway cost | ⚠️ Transactions / Liabilities products meter per connected item; NomadFi must model this | ⚠️ per-request model (vendor-reported) | ⚠️ enterprise contract | ⚠️ enterprise contract | N/A |
| Free-during-development tier | ✅ | ✅ | ⚠️ | ⚠️ | — |

### 5.9 Operational burden / lock-in

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Provider outage ≈ NomadFi outage | ⚠️ yes, for linked institutions | ⚠️ yes | ⚠️ yes | ⚠️ yes | ⚠️ per-bank |
| Data model lock-in risk | ⚠️ mitigated by NomadFi's provider-neutral snapshot contract | ⚠️ same mitigation | ⚠️ same mitigation | ⚠️ same mitigation | — |
| Exit cost from the provider | ⚠️ moderate — re-prompt for consent at new provider | ⚠️ moderate | ⚠️ moderate | ⚠️ moderate | — |

NomadFi's existing architecture (`FinancialDataProviderKind`,
`FinancialAccountSnapshot`, `FinancialDataReconciler`) already limits
lock-in because the domain model never imports vendor SDK types —
but only by convention, and only for the NomadFi-owned parts.

### 5.10 Time-to-first-value for the Decision Assistant

| Criterion | Plaid | Akoya | MX | Finicity | Direct FDX |
|---|---|---|---|---|---|
| Sandbox call → Decision Assistant benefit in < 2 weeks | ⚠️ plausible for Plaid sandbox | ⚠️ plausible | ❌ | ❌ | ❌ |
| Clean path into existing reconciler | ✅ through the existing `ExternalAggregatorFinancialDataProvider` seam | ✅ same seam | ✅ same seam | ✅ same seam | ✅ same seam |

---

## 6. Recommendation (clearly marked as inference)

*This section is interpretation, not fact. It is derived from the
evidence in §4 and §5 and from NomadFi's mission in
[`docs/MISSION.md`](../MISSION.md).*

### 6.1 Ranked plan

1. **Plaid — first technical evaluation candidate.**
   Rationale: strongest combination of self-serve sandbox, public
   pricing transparency, vendor-reported US + Canadian coverage, and
   documented webhook / sync semantics that map cleanly onto
   NomadFi's existing reconciler. Plaid Link is the most mature
   consent UX primitive among the candidates. These are necessary
   (not sufficient) conditions for NomadFi to move faster than a
   bilateral FDX approach.

2. **Akoya — first privacy / API-first comparison candidate.**
   Rationale: the strongest architectural fit with CFPB 1033 and
   FDX principles among the candidates. Production onboarding is
   less startup-self-serve, but a free sandbox makes a head-to-head
   comparison feasible. Useful as a keeper-honest second opinion
   whether or not NomadFi ends up choosing it.

3. **Reserve — MX and Mastercard / Finicity.**
   Rationale: both are serious vendors with defensible architectural
   positions and strong institutional backing, but neither's public
   onboarding posture is aligned with a pre-revenue startup. Revisit
   only if Plaid + Akoya fail the bar in §7, or once NomadFi has
   revenue that justifies an enterprise contract negotiation.

4. **Strategic reference — direct FDX / FAPI.**
   Rationale: not a practical near-term implementation, but the
   right architectural target. NomadFi's provider abstraction should
   stay shaped so that a future FDX-based adapter (per-bank, once
   one or two strategically-valuable banks are worth the bilateral
   integration) can plug into the same `FinancialDataProvider`
   contract without restructuring.

5. **Honest branch — "no provider clears the bar yet."**
   A real, valid outcome. See §7.

### 6.2 What the ranking does **not** claim

- It does **not** claim Plaid has the widest coverage in NomadFi's
  actual user base. That claim cannot be made from primary sources
  alone.
- It does **not** claim Plaid is privacy-strongest. Akoya's
  API-only architecture is, on the evidence, a cleaner privacy
  posture.
- It does **not** claim this ranking is stable forever. Regulatory
  implementation (US 1033 phase-in, Canada's consumer-driven-banking
  operationalization) will shift the board over the next 12–24
  months.

### 6.3 Immediate next action after Phase 5D

Phase 5E (code) must not start until one of two concrete outcomes:

**A — Plaid sandbox proof (≤ 1 week, time-boxed).** Validate, from
NomadFi's *own* Decision Assistant needs:

1. That `plaid-link` can execute an explicit-authorization flow that
   maps cleanly onto NomadFi's existing provider-neutral consent
   model.
2. That Transactions + Auth + Balance sandbox responses can be
   projected onto `FinancialAccountSnapshot` /
   `FinancialTransactionSnapshot` through a thin adapter without
   restructuring the reconciler.
3. That `/sync` webhooks can drive an incremental reconciliation
   that preserves the existing dedupe invariants.
4. That the modelled cost per connected active user, under
   NomadFi's expected retention, stays within a pre-revenue budget.
5. That Canadian coverage, exercised against NomadFi's target-user
   institutions, is at least partially real (not just marketed).

If (1)–(4) hold **and** (5) holds for at least one target Canadian
institution, pair the Plaid proof with an Akoya sandbox comparison
on the same criteria before any paid contract.

**B — defer.** If (1)–(4) or (5) fails, stay on FinanceKit + manual
+ CSV. This is the honest outcome the bakeoff is explicitly
structured to allow.

### 6.4 What Phase 5E cannot do

Phase 5E ships **one** adapter behind the existing
`ExternalAggregatorFinancialDataProvider` seam. It does not:

- ship two vendors concurrently ("meta-aggregator" temptation);
- modify the reconciler invariants;
- add a vendor SDK import outside the adapter file;
- add institution-manager UI beyond what the single adapter needs;
- add tax, investing-education, or reward-terms features;
- add background sync before FinanceKit background delivery has
  been validated on a real device.

---

## 7. Branch: "no provider clears the bar yet"

Exit criteria that force this branch:

- **Sandbox → production gap is too large.** The Plaid sandbox proof
  can't be replicated against a live institution within a reasonable
  production access review.
- **Unit economics don't work.** Per-connected-user cost modelled
  against NomadFi's retention exceeds the pre-revenue budget by
  > 2×.
- **Canadian coverage fails.** None of NomadFi's target-user Canadian
  institutions (RBC, CIBC, TD, Scotia, BMO, Tangerine, Simplii) are
  actually reachable with OAuth / API-first flows through any
  evaluated provider.
- **Consent UX is incompatible with the product.** Either Plaid
  Link's copy cannot be tuned to meet 1033's disclosed-aggregator
  and minimum-necessary posture, or Akoya's production onboarding
  requires disclosures NomadFi can't honestly make at its size.

Default behavior if this branch fires:

- Do not implement Phase 5E.
- Keep `ExternalAggregatorFinancialDataProvider` as the explicit
  "not enabled in this build" seam.
- Continue Phase 5C outside-repo work (Apple entitlement +
  real-device bakeout) because that path costs nothing in vendor
  dollars.
- Revisit this memo once CFPB 1033 is materially operationalized,
  or once Canada's Consumer-Driven Banking regime publishes
  developer-accessible endpoints.

This branch is a valid, well-defined outcome — not a failure.

---

## 8. Known unknowns

Flagging these explicitly so a follow-up contributor (or a future
Phase 5E run) knows where public-document research hits its limits.

1. **Production institutional coverage per provider, for NomadFi's
   target-user FIs.** Vendor-reported only. Resolution path:
   sandbox proof + explicit production access conversation.
2. **OAuth-first conversion rate at large US FIs per provider.**
   Vendor-reported only. Resolution path: real-device usability
   bakeout during Phase 5E sandbox phase.
3. **Real Canadian coverage.** Marketed by Plaid; not operationally
   verifiable from public sources. Resolution path: sandbox
   validation against target-user institutions.
4. **TT coverage.** No evidence from any primary source. Unlikely to
   resolve in the near term.
5. **NomadFi's actual per-user cost curve.** Depends on retention,
   sync cadence, and product selection — none of which are decided
   until Phase 5E.
6. **Sandbox-to-production fidelity.** Not knowable from docs alone.
   Resolution path: side-by-side sandbox and production calls with
   an early cohort during Phase 5E.
7. **Future 1033 / Consumer-Driven Banking timeline.** Rulemaking
   and litigation are moving. Research this memo once rulemaking
   stabilizes.
8. **Investment-account fidelity.** NomadFi's investing-education
   roadmap is Phase 8 and secondary; not a Phase 5D decider.

---

## 9. How this memo ties into the existing roadmap

- The in-code plumbing Phase 5A + 5B + 5C established is **already**
  compatible with every candidate in §4, because the NomadFi domain
  model never imports a vendor SDK and the reconciler only reads
  provider-neutral snapshots. No structural rework is needed before
  Phase 5E.
- [`FinanceKitFeasibility.md`](./FinanceKitFeasibility.md) remains
  the operational doc for the Apple-native path. This bakeoff is
  purely about the layer *beyond* FinanceKit.
- `docs/TIMELINE.md` is updated alongside this memo so
  - Phase 5A, 5B, 5C-in-code are marked shipped,
  - the outside-repo Phase 5C blockers are called out,
  - Phase 5D is this memo,
  - Phase 5E is conditional on this memo's recommendation (§6.3),
  - Phase 5F stays parked behind real production use.

---

## 10. Source anchors (primary only)

Regulator / government:

- CFPB 1033:
  - [§ 1033.211 Covered data](https://www.consumerfinance.gov/rules-policy/regulations/1033/211/)
  - [§ 1033.401 Authorization](https://www.consumerfinance.gov/rules-policy/regulations/1033/401/)
  - [§ 1033.411 Disclosure](https://www.consumerfinance.gov/rules-policy/regulations/1033/411/)
  - [§ 1033.421 Third-party obligations](https://www.consumerfinance.gov/rules-policy/regulations/1033/421/)
  - [§ 1033.431 Aggregator use](https://www.consumerfinance.gov/rules-policy/regulations/1033/431/)
  - [§ 1033.441 Retention](https://www.consumerfinance.gov/rules-policy/regulations/1033/441/)
- Government of Canada — Consumer-Driven Banking:
  - [Department of Finance Canada: Consumer-Driven Banking](https://www.canada.ca/en/department-finance/programs/financial-sector-policy/consumer-driven-banking.html)
  - [FCAC role](https://www.canada.ca/en/financial-consumer-agency.html)
- Central Bank of Trinidad and Tobago:
  - [central-bank.org.tt](https://www.central-bank.org.tt/)

Standards bodies:

- [FDX mission](https://financialdataexchange.org/FDX/FDX/About/About-FDX.aspx)
- [FDX 6.4 release](https://financialdataexchange.org/FDX/FDX/News/Announcements/FDX_Announces_Spring_2025_API_Release_6_4.aspx)
- [OpenID FAPI working group](https://openid.net/wg/fapi/)

Apple (for FinanceKit context):

- [FinanceKit framework](https://developer.apple.com/documentation/financekit)
- [FinanceKit overview](https://developer.apple.com/financekit/)
- [FinanceStore](https://developer.apple.com/documentation/financekit/financestore)

Vendor primary documentation:

- Plaid:
  [Docs home](https://plaid.com/docs/),
  [Transactions](https://plaid.com/docs/transactions/),
  [Transactions API](https://plaid.com/docs/api/products/transactions/),
  [Balance](https://plaid.com/docs/api/products/balance/),
  [Auth](https://plaid.com/docs/api/products/auth/),
  [Institutions](https://plaid.com/docs/institutions/),
  [OAuth](https://plaid.com/docs/link/oauth/),
  [Pricing](https://plaid.com/pricing/),
  [Billing mechanics](https://plaid.com/docs/account/billing/),
  [Webhooks](https://plaid.com/docs/api/webhooks/),
  [Plaid in Canada](https://plaid.com/en-ca/)
- Akoya:
  [Overview](https://akoya.com/),
  [Developer portal](https://developer.akoya.com/),
  [Fintechs](https://akoya.com/fintechs),
  [Products](https://akoya.com/products-overview),
  [Balances](https://akoya.com/products/balances),
  [Investments](https://akoya.com/products/investments),
  [Pricing](https://akoya.com/pricing)
- MX:
  [Open Finance](https://www.mx.com/open-finance/),
  [Use cases](https://www.mx.com/use-cases/open-finance/),
  [Docs](https://docs.mx.com/)
- Mastercard / Finicity:
  [Mastercard Open Banking](https://www.mastercard.com/us/en/business/open-banking.html),
  [Mastercard-Finicity press release](https://www.mastercard.com/news/press/press-releases/2020/june/mastercard-to-acquire-finicity-to-advance-open-banking-strategy/),
  [Mastercard Open Banking developer](https://developer.mastercard.com/product/open-banking-us),
  [Finicity developer docs](https://developer.finicity.com/)
