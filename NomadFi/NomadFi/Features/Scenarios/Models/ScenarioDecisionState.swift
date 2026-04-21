// ScenarioDecisionState.swift
// NomadFi
//
// The toggleable guardrails Ariel can confirm from the Scenario Decision
// Brief detail view. Nothing here is persisted in Phase 3 — the values
// live only as local view state so the engine can re-run deterministically
// as the user confirms each check.

import Foundation

/// User-supplied checks that feed the decision engine. Every flag is
/// `false` by default so the engine is never allowed to recommend a
/// credit-card path on the user's behalf without explicit confirmation.
struct ScenarioDecisionState: Sendable, Equatable {

    /// Ariel has opened the Chase app/statement and confirmed available
    /// credit comfortably exceeds the USD checkout amount plus a buffer.
    var chaseAvailableCreditConfirmed: Bool = false

    /// Ariel has the ability and intent to pay the Chase balance before
    /// the next statement closes, so the purchase does not report high
    /// utilization to the bureaus and does not accrue interest.
    var canPayBeforeStatementClose: Bool = false

    /// The Wise USD balance is large enough to cover the USD checkout
    /// amount without requiring a mid-transaction top-up or Wise FX.
    var wiseBalanceSufficient: Bool = false

    /// The Airbnb host has confirmed they will receive packages before
    /// arrival (or delivery is timed to land after arrival).
    var airbnbPackageReceiptConfirmed: Bool = false

    /// Ariel has reviewed the cart for paid / overnight shipping lines
    /// and accidental Subscribe & Save selections.
    var cartShippingReviewed: Bool = false
}
