// ScenarioPaymentOption.swift
// NomadFi
//
// A single row in the payment-option comparison rendered inside the
// Scenario Decision Brief detail sheet.

import Foundation

/// Identifier for the distinct payment paths the engine evaluates for
/// Scenario 1. Used as both the option's stable ID and a switch key on
/// the rendered stance.
enum ScenarioPaymentMethod: String, Sendable, Equatable, CaseIterable {
    case chaseFreedomRiseUSD
    case wiseUSD
    case amexCobaltUSD
    case amexCobaltCADWithACC
}

/// The engine's stance on a given payment option, given the current
/// ``ScenarioDecisionState``.
enum ScenarioOptionStance: String, Sendable, Equatable {
    /// Conditionally preferred — only if the guardrails for this option
    /// are all confirmed true.
    case conditionallyPreferred
    /// Safe operational fallback — use when the preferred option's
    /// guardrails are not yet satisfied.
    case safeFallback
    /// Requires additional verification before it can even be compared
    /// honestly.
    case needsVerification
    /// Explicitly discouraged for this scenario until a better source
    /// proves otherwise.
    case discouraged
}

/// A single payment option as it appears in the Scenario Decision Brief.
struct ScenarioPaymentOption: Identifiable, Sendable, Equatable {
    var id: ScenarioPaymentMethod { method }

    let method: ScenarioPaymentMethod
    let title: String
    let subtitle: String
    let costLabel: String
    let upside: String
    let downside: String
    /// Evidence tags that qualify the numbers/claims on this option.
    let evidence: [ScenarioEvidenceTag]
    /// The engine's current stance on this option.
    let stance: ScenarioOptionStance
}
