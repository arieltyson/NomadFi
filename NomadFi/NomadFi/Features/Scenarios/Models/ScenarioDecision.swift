// ScenarioDecision.swift
// NomadFi
//
// The engine's deterministic output for a scenario. Nothing in here is
// a live claim — every field is derived from `ScenarioFacts` (which
// came from screenshots) and `ScenarioDecisionState` (which came from
// explicit user confirmations persisted in `ScenarioDecisionRecord`).

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

/// Computed values the engine derives from user-confirmed numeric
/// inputs. Every field is `nil` when the underlying input is missing,
/// so the UI can render an honest "needs input" placeholder instead of
/// a fabricated number.
struct ScenarioComputedValues: Sendable, Equatable {

    /// Pay-in-USD checkout amount echoed back for UI convenience.
    let checkoutAmountUSD: Double

    /// Conservative safety buffer on top of checkout when testing
    /// Chase available credit.
    let chaseAvailableCreditSafetyBufferUSD: Double

    /// The amount Chase available credit must cover for the Chase
    /// guardrail to pass: `checkout + buffer`.
    let chaseRequiredAvailableCreditUSD: Double

    /// Projected Chase statement balance after the purchase posts —
    /// `nil` while the user has not entered a current balance.
    let projectedChaseBalanceUSD: Double?

    /// Projected Chase utilization after the purchase posts, as a
    /// fraction in `[0, 1+]` — `nil` while inputs are missing.
    let projectedChaseUtilizationPercent: Double?

    /// Zero-balance reference utilization — always known from the total
    /// limit alone. Labelled in the UI as the "if paid off" reference.
    let zeroBalanceChaseUtilizationPercent: Double?

    /// Whether Chase available credit (user-entered) comfortably covers
    /// checkout plus the buffer. `nil` when no available credit is set.
    let chaseHasSufficientAvailableCredit: Bool?

    /// Whether Wise USD balance (user-entered) covers the checkout.
    /// `nil` when the user has not entered a balance.
    let wiseBalanceCoversCheckout: Bool?
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

    /// Computed values surfaced on the detail sheet's guardrail card —
    /// projected utilization, buffer math, Wise coverage check.
    let computedValues: ScenarioComputedValues

    /// Official sources the brief cites in its Sources section. The app
    /// never fetches these; it only points users to them for their own
    /// verification.
    let citations: [ScenarioCitation]
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
    /// Evidence tag for the item — always `.needsUserInput` in Phase 4,
    /// but kept polymorphic for later scenarios that mix sources.
    let evidence: ScenarioEvidenceTag
}
