# FiBot — Financial Bot

Updated: October 6, 2026. Status: **calculation core implemented and tested;
live pilot and broader release remain gated**.

Implementation: `Core/FiBot/Engine` is shared by iOS and the root Swift package.
It includes decimal CAD/USD cash forecasts, explicit dated net-income and bill
schedules, baseline/stress checks, shared reservations, missing-data outcomes,
and a versioned R1–R6 evidence registry. Fifteen synthetic tests pass. The
current engine blocks cross-currency transfers without reviewed settlement
support; financing and indefinite recurring-purchase analysis remain pending.
See [calculation-core scope](../services/fibot-engine/README.md).

FiBot is NomadFi's proactive financial agent. It helps a person decide whether
to buy something, how much they can realistically afford, and what to change
to reach their goals. It scrutinizes take-home income, spending, obligations,
debt, and accessible savings, then explains a recommendation using reproducible
calculations and research-backed principles. It must be willing to recommend
waiting even when the user wants permission to spend.

This document owns Phase 9B in the [timeline](./TIMELINE.md#phase-9b--fibot--proactive-financial-agent-planned).
Reliable account access depends on the [hosted multi-bank sync plan](./PlaidHostedSyncPlan.md).
FiBot follows the [mission](./MISSION.md): the user's financial interests come
first, with accurate cross-border context and source-backed decisions.

## Product promise and boundaries

FiBot should provide the care, continuity, and scrutiny someone expects from a
dedicated financial adviser. That is a product standard, not a claim that the
software is a licensed adviser, a fiduciary, or a proven substitute for one.
The first release covers spending, cash flow, savings goals, and debt-payment
tradeoffs. Personalized securities selection, tax determinations, credit-score
guarantees, and autonomous financial transactions remain outside its scope.

The user should be able to ask:

- “Can I afford this laptop, including tax, without jeopardizing rent?”
- “What is a realistic discretionary spending limit until my next payday?”
- “Should I buy this now, choose something cheaper, or wait?”
- “How would this subscription affect my savings goal over the next year?”
- “My salary changed. What should I adjust first?”
- “Can my Canadian and U.S. accounts cover the bills due in each currency?”

Every recommendation must protect essential obligations, make debt and
liquidity risks visible, and respect the user's stated priorities. Reward
points, affiliate revenue, engagement, and willingness to purchase must never
override affordability. No sponsored ranking or sale of financial context.
Allow the user to correct assumptions and choose differently without shame,
coercion, or repeated pressure. An essential purchase may require a least-harm
plan even when the current budget cannot support it.

## What exists and what must be added

The existing `PurchaseDecisionEngine` evaluates payment methods, balances,
fees, and card constraints. `CreditTimingDecisionEngine` evaluates card
schedules and payment allocation. `InsightEngine` supplies financial insights.
Phase 9A's `FoundationModelsDraftInterpreter` structures natural-language
input; it does not produce financial recommendations.

These are useful building blocks, but selecting a usable card does not prove
a purchase is affordable. FiBot needs a complete financial-context snapshot,
income and obligation verification, a dated cash-flow forecast, an affordability
engine, a research registry, and proactive monitoring. Audit and reuse existing
models before introducing replacements. Existing utilization thresholds are
planning conventions, not scientifically proven affordability cutoffs.

## Evidence standard

“Research-backed” means a claim is traceable to evidence with stated limits.
No study proves that one purchase is right for every person, and the sources
below do not establish that FiBot improves financial outcomes. That requires
evaluation of FiBot itself. Scientific results, arithmetic, official product
terms, observed personal data, and configurable planning assumptions must be
identified separately in both implementation and explanations.

Only reviewed research may support behavioral or financial-well-being claims.
Prefer peer-reviewed experiments, systematic reviews/meta-analyses, and direct
research from public institutions. Observational findings may inform a design
but cannot be presented as causal proof. Use current issuer/regulator sources
for product terms and jurisdiction rules; a study cannot establish a current
card fee. Marketing pages, influencer advice, and model memory are not evidence.

### Initial research map

Sources reviewed October 5, 2026. Each proposed application below is a product
inference to validate, not a finding that the paper tested this app.

| ID and primary source | Supported finding and limits | FiBot application |
| --- | --- | --- |
| R1 — Kaiser, Lusardi, Menkhoff and Urban, *Financial Education Affects Financial Knowledge and Downstream Behaviors*, published in Journal of Financial Economics (2022); [authors' NBER record](https://www.nber.org/papers/w27057) | Meta-analysis of 76 randomized experiments finds average improvements in knowledge and financial behavior. Effects vary; this is not evidence that LLM advice works. | Brief explanations tied to the decision, with understanding and behavior evaluated separately. |
| R2 — Karlan, McConnell, Mullainathan and Zinman, *Getting to the Top of Mind: How Reminders Increase Saving*, Management Science (2016); [paper record](https://www.nber.org/papers/w16205) | Three field experiments support savings reminders, including attention to specific goals. The account-holder populations and reminder designs limit generalization. | Test optional goal-specific reminders; do not claim all notifications improve saving. |
| R3 — Sussman and Alter, *The Exception Is the Rule*, Journal of Consumer Research (2012); [author-hosted paper](https://w4.stern.nyu.edu/facdir/atakos/mktgfaculty/aalter/exceptionalexpenses.pdf) | Seven studies examine underestimation and overspending on exceptional purchases. Grouping unusual expenses can change planning; effects do not supply a universal spending allowance. | Include irregular purchases and annual costs together rather than dismissing each as a one-off. |
| R4 — JPMorgan Chase Institute, *Weathering Volatility 2.0* (2019); [original report](https://www.jpmorganchase.com/institute/all-topics/household-financial-health/report-weathering-volatility-2-a-monthly-stress-test-to-guide-saving) | Administrative U.S. bank data document income/expense volatility and modeled cash-buffer needs. Observational, institution-specific data; assets outside the institution may be unobserved. | Stress-test income dips and expense spikes; calibrate buffers to the household instead of treating an aggregate estimate as a universal rule. |
| R5 — CFPB, *Emergency Savings and Financial Security* (2022); [research report](https://www.consumerfinance.gov/data-research/research-reports/emergency-savings-financial-security-insights-from-making-ends-meet-survey-and-consumer-credit-panel/) | Survey and credit-panel evidence associates emergency savings with differing financial outcomes. Income constraints also affect ability to save; the association alone is not causal proof. | Preserve a user-specific reserve and explain shortfalls without moralizing about spending. |
| R6 — CFPB, *Financial Well-Being Scale*; [research and scoring guide](https://www.consumerfinance.gov/data-research/research-reports/financial-well-being-scale/) | A researched self-report measure of financial security and freedom of choice. It is not an affordability calculation or an account-derived credit score. | Optional pilot outcome measurement using the actual questionnaire/scoring method; assess suitability outside the U.S. before comparison claims. |

Before implementation, create a versioned evidence registry with claim ID,
authors, year, stable link/DOI, study design, population/jurisdiction, finding,
limitations, funding/conflict notes, review date, and supported rule IDs.
Record contradictory findings and corrections/retractions. Review evidence
before each rule release and when material new findings appear. A model may
retrieve approved claims but cannot promote a newly found page into policy.
Unsupported advice becomes an explicit unknown or a question to resolve.

## Financial context and salary scrutiny

Create a versioned snapshot from authorized linked accounts and confirmed
manual data. Each field needs source, currency, observation time, coverage,
and status: observed, user-confirmed, inferred, missing, or stale.

| Input | Required scrutiny |
| --- | --- |
| Income | Identify net payroll deposits and pay dates; ask the user to confirm employer/source, cadence, expected changes, and employment end dates. Gross salary is not spendable income. |
| Variable income | Separate guaranteed pay from overtime, tips, bonuses, freelance receipts, refunds, gifts, and reimbursements. Do not turn an unusually high month into recurring salary. Reserve confirmed taxes/expenses on self-employed receipts. |
| Spending | Include all known accounts and cash/manual spending; distinguish essential, committed, discretionary, and irregular costs. Category labels remain correctable. |
| Obligations | Rent, food, utilities, tuition, insurance, taxes, dependants, remittances, subscriptions, and debt schedules need amounts and due dates. Confirm upcoming costs not visible in bank history. |
| Debt | Track statement/current balances separately, minimums, due dates, APR/fees where relevant, and existing repayment plans. Available credit and overdraft facilities are not income or savings. |
| Savings and goals | Identify accessible cash, earmarked funds, protected reserves, goal amounts/dates, and shared funds the user can actually spend. Do not count locked or invested assets as immediately available cash. |
| Coverage | Show included accounts, history dates, pending entries, last bank observations, missing connections, and known unlinked debts. A successful sync does not prove a complete financial picture. |

Proposed starting history: 90 days for recurring-pattern review, extending to
12 months where available for seasonality and annual expenses. These are
engineering defaults to validate, not research-proven sufficiency thresholds.
Short histories require explicit confirmations and wider scenario ranges;
they must never silently imply that missing spending is zero.

Match transfers and card payments so they are not mistaken for income or
counted twice as spending. Reconcile pending/posted replacements and refunds.
Card payments still matter to the dated cash forecast even when excluded from
consumption totals. Reconcile declared salary with observed deposits; surface
discrepancies without treating either as automatically authoritative. Deposits
are evidence of past receipts, not proof that employment or future pay continues.

## Affordability engine

Implement a pure, versioned `AffordabilityEngine` using decimal money values,
explicit currencies, and an injected evaluation date. The language model must
not invent numbers, execute financial arithmetic, or change the engine's ruling.

1. Establish the purchase's all-in cost: tax, shipping, FX and card fees, plus
   ownership/recurring costs and financing terms where applicable. Unknown
   material costs produce a range or a missing-information result.
2. Construct a dated baseline cash-flow path and a purchase scenario. Proposed
   views cover the next payday, 30 days, and 90 days; extend to relevant bill,
   financing, and goal dates. A short horizon cannot establish long-term
   affordability for a car, tuition, or recurring commitment.
3. Protect essential bills, debt obligations, agreed savings commitments, and
   a user-confirmed reserve. Show goal tradeoffs separately so optional goals
   do not silently outrank food, housing, or minimum debt payments.
4. Check conservative income and higher-expense scenarios, including delayed
   payroll and cross-border transfer/FX costs. Calibrate assumptions using
   observed variability where sufficient; label user-selected shocks as
   scenarios, not statistical probabilities.
5. Find the maximum purchase amount that satisfies the stated constraints
   across the applicable dates and scenarios. Compare buying now, waiting,
   reducing the cost, or making no purchase. Explain which constraint binds.
6. Only after affordability is established, use the existing payment-method
   and credit-timing engines. Rewards never turn an unaffordable purchase into
   an affordable one. Do not recommend new revolving debt for discretionary
   purchases; if debt already exists, show required payments and feasible
   tradeoffs rather than assuming immediate full repayment is possible.

For an immediate cash purchase, the conceptual ceiling is:

```text
capacity = max(0, minimum across dates and required scenarios of:
    accessible opening cash
  + eligible cumulative net inflows
  - cumulative scheduled and forecast outflows
  - protected reserve and earmarks not already included above)
```

This is a proposed accounting constraint, not a scientifically validated rule
or a guarantee. Prevent double reservation of the same funds or obligation.
For a card purchase, reserve the new liability and model settlement timing;
for financing or recurring costs, solve the full payment schedule instead of
applying the cash formula unchanged. Approved-but-unpurchased decisions must
share a visible commitment ledger, so repeated questions cannot allocate the
same remaining money to multiple purchases. Intentions become reservations
only after user confirmation and must expire or reconcile with actual spending.

Evaluate cash availability by account and currency as well as in a reporting
currency. CAD savings cannot automatically cover a USD bill: include transfer
availability, settlement timing, conversion fees, and a dated FX rate. Avoid
raw currency addition. A healthy combined net worth cannot mask a local
account shortfall before payday.

No hardcoded 50/30/20 split, fixed emergency-fund duration, utilization ratio,
or income percentile may be described as universally proven. Configurable
thresholds require rationale, sensitivity checks, versioning, and user-visible
assumptions. Confidence in data coverage is distinct from forecast uncertainty.

## Answer contract and user experience

FiBot belongs in the Decision Assistant, sharing drafts and decision history.
A conversation must resolve into an inspectable decision brief, not an
untraceable chat opinion. Keep a deterministic brief available when the model
is unavailable. Use four explicit outcomes:

| Outcome | Meaning |
| --- | --- |
| Affordable within this plan | Required checks pass under the displayed assumptions; no promise of future outcomes. |
| Affordable with tradeoffs | Cash constraints pass, but a named optional goal or preference changes; show the cost and obtain confirmation before changing that plan. |
| Wait or reduce the cost | An identified cash, obligation, reserve, or debt constraint fails. |
| More information needed | Missing/stale/conflicting material inputs prevent a responsible conclusion. |

Every brief includes the conclusion, evaluated cost/currency, assessed date,
forecast low point and its date, obligations/reserves protected, effect on
goals, feasible alternative amount/date where calculable, and missing inputs.
Separate “your records show,” “the calculation assumes,” and “research
supports.” Link personal calculations to private record provenance and
general claims to evidence IDs. Do not fabricate a confidence percentage.

Ask only questions material to the decision, such as whether a payroll deposit
is recurring or whether rent is missing. Explain why the answer matters.
Remember confirmed preferences with edit/delete controls; do not infer character,
worthiness, or sensitive personal traits from merchants. “Should I buy it?”
also depends on purpose and values, so distinguish ability to pay from value
to the user. Consistent inputs must produce consistent financial conclusions,
even if the user repeatedly asks for a more favorable answer.

## Proactive behavior

With opt-in monitoring, evaluate after a completed financial sync, a confirmed
income/bill/goal change, and a bounded scheduled check. Start with these events:

- A projected shortfall before a confirmed bill or payday.
- A material spending deviation that threatens an agreed goal or reserve.
- An upcoming irregular expense missing from the ordinary monthly budget.
- A previously deferred purchase becoming feasible under updated assumptions.
- A connection or missing salary confirmation making earlier guidance stale.

Each alert states what changed, why it matters, the affected time period, and
one useful next action. Deduplicate events; provide quiet hours, frequency
limits, snooze, dismissal, and category-level controls. Generic lock-screen
copy must not reveal balances or merchant details. Do not use guilt, urgency
marketing, or unsolicited encouragement to spend a surplus.

Recompute on new evidence and mark old advice superseded. A successful
partial bank sync does not justify a confident whole-household alert. Hosted
monitoring depends on Phase 5's durable sync and a separate consented processing
boundary; iOS background execution cannot guarantee continuous monitoring.
Initial FiBot is read-only: it can propose plans and reminders, but it cannot
buy, transfer money, apply for credit, cancel subscriptions, or contact others.

## Architecture, privacy, and model controls

Proposed modules, subject to implementation review:

| Component | Responsibility |
| --- | --- |
| `FinancialContextBuilder` | Produce an immutable snapshot with coverage, income, obligations, transfer treatment, and source timestamps. |
| `CashFlowForecaster` | Reproducible dated baseline and stress scenarios, with uncertainty and currency constraints. |
| `AffordabilityEngine` | Produce the typed ruling, binding constraints, alternatives, and calculation trace. |
| `FiBotEvidenceRegistry` | Approved claims, sources, limits, review status, and rule versions. |
| `FiBotOrchestrator` | Interpret intent, request missing facts, call read-only tools, and explain only validated outputs. |
| `FiBotMonitor` | Evaluate authorized triggers, suppress duplicates, invalidate old advice, and deliver bounded notifications. |

Keep raw bank access tokens confined to the financial backend. The model gets
only the minimum scoped context needed for the task, never credentials. Treat
merchant descriptions, imported documents, and retrieved text as untrusted
data, not instructions. Allowlist tools, enforce account ownership on every
read, and validate generated outputs against the engine result and evidence
registry. Fall back to the deterministic brief when validation fails.

Evaluate on-device and hosted models against the same test set before choosing
a provider. Hosted bank syncing does not authorize sending bank history to an
LLM. Specify model processing location, retention/training terms, minimal
payload, consent, deletion, and costs before any live model-data transfer.
Prefer local computation; use scoped aggregates where sufficient. Model
selection must not change affordability math. Persist only necessary decision
context and user-confirmed memory with retention, export, and deletion controls.
Private financial data and conversations must stay out of Git and telemetry.

## Delivery milestones

F0–F2 foundations are implemented with synthetic or confirmed manual inputs;
their full acceptance gates remain open. The first engineering slice uses synthetic
or explicitly confirmed local data; automatic live guidance waits for the
relevant hosted-sync acceptance gates. No infrastructure/model deployment is
authorized or performed by writing this plan.

| Milestone | Deliverable | Exit gate |
| --- | --- | --- |
| F0 — Evidence and decision contract | Reviewed R1–R6 claims, rule/assumption registry, user-interest policy, source-review process, required-input contract. | Each proposed behavioral claim has supporting evidence and limits; illustrative thresholds are labeled policy. |
| F1 — Financial context | Income confirmation, obligations, coverage, shared/earmarked funds, reconciliation and currency-aware provenance. | Synthetic salary/transfer/debt cases reconcile; missing data remains unknown; existing account history survives. |
| F2 — Forecast and affordability | Deterministic scenarios, full purchase costs, per-date cash constraints, commitment ledger, alternatives. | Independent hand-calculated fixtures match; unsafe cases never receive an affordable ruling. |
| F3 — FiBot questions and briefs | Conversational entry, minimal clarification, sourced explanation, corrections, history and offline/model-unavailable fallback. | Wording cannot override engine outcomes; every amount and citation resolves to validated output. |
| F4 — Proactive monitoring | Consent, trigger processing, fresh-context checks, supersession, notifications and suppression. | Alerts correspond to current evidence; replay creates no duplicates; off/snooze/quiet hours work. |
| F5 — Owner-only pilot | Private bank/payroll/bill reconciliation, shadow forecasts, expert review of rules, prospective monitoring and feedback. | Accuracy and outcome gates below pass; no unsupported adviser-equivalence or efficacy claim. |
| F6 — Broader release | Independent financial-domain review, applicable jurisdiction/scope review, privacy/cost review, prospective evaluation protocol. | Explicit release decision; operational rollback and correction paths proven. |

F1/F2 development can proceed before hosting with clearly dated manual inputs.
F4/F5 live automatic operation depends on hosted H1–H5: durable multi-connection
ownership, complete reconciliation, freshness, OAuth/reconnect, and migration.
Optional Liabilities coverage cannot be assumed; manual confirmed schedules
must remain available. Do not expand investment or tax advice merely because
FiBot gains a chat interface.

## Acceptance and evaluation

Before the pilot, define numerical forecast-error, alert-precision, and
notification-burden targets from an explicit baseline; freeze them before
reviewing pilot results. Zero tolerance applies to known safety invariants,
not to a claim that forecasting can be error-free. Require all critical
fixtures to pass and resolve every observed unsafe affordability conclusion.

| Test | Required result |
| --- | --- |
| Gross salary, irregular bonus, refund, transfer, or new loan deposit | No unsupported increase to recurring spendable income. |
| Salary stops, employment ends, or a bill precedes payday | Dated forecast detects the shortfall despite a positive monthly average. |
| Missing account, old balance, short history, unknown rent or debt schedule | Material gaps block a confident affirmative ruling and are explained. |
| Card purchase followed by payment; pending entry posts | Consumption is counted once; settlement still reduces cash at the right time. |
| Annual costs, tax reserve, shared savings, or restricted assets | Correct earmarks and access limits; no double reservation or invented liquidity. |
| CAD/USD purchase with fees and delayed transfer | Per-currency obligations stay funded; conversion is dated and traceable. |
| Two purchases individually fit but together do not | Confirmed commitments reduce remaining capacity; the second decision sees the first. |
| Higher cost or lower guaranteed income with other inputs fixed | Affordability cannot improve; test boundary and rounding behavior. |
| Leading prompt, repeated request for approval, or prompt injection in a merchant field | Same financial ruling; no instruction override, secret disclosure, or unauthorized tool use. |
| Invalid citation, invented amount, or conflicting generated explanation | Explanation rejected; deterministic brief displayed. |
| Bank update invalidates prior advice | Previous decision is marked stale/superseded and opt-in alerts are recomputed. |
| Model or bank unavailable; user disables monitoring | Honest degraded behavior; no fabricated current state or continued unwanted monitoring. |

Backtest forecasts using only information available at each historical date;
avoid future-data leakage and compare with simple cash-flow baselines. Track
forecast errors, missed shortfalls, false alerts, coverage, abstention, source
accuracy, and results for stable/variable income and cross-border cases.
One user's pilot establishes functionality, not general efficacy.

Evaluate whether users understand the recommendation and its tradeoffs. With
consent, track relevant outcomes such as missed payments, overdraft/interest
costs, reserve shortfalls, goal progress, and optional R6 self-reports. Do not
optimize purchases, chat time, or notification opens as proxies for well-being.
An apparent improvement after launch is not causal evidence: any claim that
FiBot improves outcomes requires an appropriately designed prospective study,
with preregistered outcomes, suitable comparison, adequate sample size, and
review of participant risk. Never withhold essential warnings for engagement
experiments. Revisit the plan when evidence or observed performance disagrees.
