// ScenarioDecision.swift
// NomadFi
//
// The engine's deterministic output for a scenario. Nothing in here is
// a live claim — every field is derived from `ScenarioFacts` (which
// came from screenshots) and `ScenarioDecisionState` (which came from
// explicit user confirmations).

import Foundation

/// The primary payment path the engine currently recommends.
enum ScenarioRecommendedPath: String, Sendable, Equatable {
    /// Fix the cart before choosing a payment method.
    case reviewCartFirst
    /// Chase Freedom Rise, paid in USD, with utilization guardrails
    /// confirmed by the user.
    case chaseFreedomRiseUSD
    /// Wise USD card or balance, paid in USD.
    case wiseUSD
    /// Blocked on more user input — the engine refuses to pick.
    case awaitingUserInput
}

/// The complete deterministic output rendered on the detail sheet.
struct ScenarioDecision: Sendable, Equatable {

    /// One-sentence top ruling used as the primary copy on the
    /// dashboard card and as the lede of the detail sheet.
    let ruling: String

    /// The engine's currently recommended path after applying the
    /// ``ScenarioDecisionState``.
    let primaryPath: ScenarioRecommendedPath

    /// Bulleted rationale shown under the ruling.
    let rationale: [String]

    /// Outstanding user checks the engine still needs before it can
    /// move off ``ScenarioRecommendedPath/awaitingUserInput`` or off a
    /// ``ScenarioOptionStance/safeFallback`` branch.
    let outstandingChecks: [String]

    /// Comparison rows for the detail sheet's payment table.
    let paymentOptions: [ScenarioPaymentOption]

    /// Cost breakdown facts, already labeled by evidence tier, for the
    /// detail sheet's cost section.
    let costBreakdown: [ScenarioCostLine]

    /// Hard guardrails that must hold regardless of which branch wins.
    let hardRules: [String]

    /// Before-checkout checklist rendered under the ruling.
    let beforeCheckoutChecklist: [ScenarioChecklistItem]
}

/// A single cost-breakdown line (e.g. "USD checkout: USD 342.67").
struct ScenarioCostLine: Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let value: String
    let evidence: ScenarioEvidenceTag
    let note: String?
}

/// A single user-facing checklist item shown in the detail sheet.
struct ScenarioChecklistItem: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    /// Evidence tag for the item — always `.needsUserInput` in Phase 3,
    /// but kept polymorphic for later scenarios that mix sources.
    let evidence: ScenarioEvidenceTag
}
