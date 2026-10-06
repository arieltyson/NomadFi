# Shared FiBot calculation core

`swift test --scratch-path /tmp/NomadFiFiBotBuild` runs synthetic financial
fixtures. `swift run fibot-evaluate` reads one bounded JSON request from stdin
and returns a deterministic decision. The request contains `context`, `purchase`
and an optional `policy`; `FiBotMoney.amount` is a decimal **string**. Never pass
private financial input as command-line arguments or commit it as a fixture.

The Swift package compiles the same source files included by the iOS app.
There is no JavaScript reimplementation of the financial arithmetic. The CLI
has no provider credentials, network calls, model calls or financial logging.

Current scope is an immediate CAD/USD cash allocation, with confirmed dated
ownership costs. A card's credit limit, invested assets and locked funds cannot
fund it. Cross-currency transfers require further quote/settlement support and
currently produce a missing-information result. Financing and open-ended
recurring purchases must not be passed off as a one-time cash purchase.

The versioned evidence registry links six sources and states their study limits,
funding-review limits, and applicable rules. Its source review is not independent
financial-domain sign-off. Scenario percentages, dates and freshness windows
are configurable product assumptions, not scientific safety guarantees.

Confirmed net-income and bill schedules have explicit end dates. Context
confirmation expires after 30 days; account balances have a separate freshness
gate. Confirmed commitments share capacity and partial scheduled settlement
does not release the remainder. Optional-goal tradeoffs require changing and
reevaluating the plan before reserving a purchase.

Release gates remain in `docs/FiBot.md`: private reconciliation, expert review,
prospective forecast/alert evaluation, and explicit hosted/model processing
consent. Passing deterministic fixtures does not establish financial efficacy.
