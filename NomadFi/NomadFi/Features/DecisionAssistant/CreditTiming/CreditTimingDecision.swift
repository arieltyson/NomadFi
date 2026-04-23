// CreditTimingDecision.swift
// NomadFi
//
// Top-level output of the Credit Timing engine — what the brief sheet
// renders and what the Decision Assistant hero summarises.

import Foundation

/// The Credit Timing engine's full output. Pure value type; no
/// SwiftData, no SwiftUI. Safe to hand to tests, dialog formatters,
/// or future App Intents.
struct CreditTimingDecision: Sendable, Equatable {

    /// Portfolio-level ruling derived from the worst per-card ruling.
    let ruling: CreditTimingRuling

    /// Per-card assessments, sorted by severity so the brief sheet
    /// shows the most actionable card first.
    let cardAssessments: [CreditTimingCardAssessment]

    /// Aggregated missing-data / verification checks across every
    /// card. De-duplicated so the user isn't told the same thing
    /// twice.
    let missingDataChecklist: [String]

    /// Hard rules that never depend on the engine's inputs — pinned
    /// here so the brief sheet always shows them alongside the
    /// recommendation.
    let hardRules: [String]

    /// Official-source citations (CFPB + myFICO). Never fetched —
    /// only linked for user verification.
    let citations: [ScenarioCitation]

    /// Portfolio-wide cross-card payment-allocation plan. Always
    /// present — empty `groups` means no eligible cards. The plan is
    /// a target sheet unless the UI passed a budget, in which case
    /// `appliedBudget` echoes the user's input and each line carries
    /// a `suggestedPayment`.
    let paymentAllocation: CreditPaymentAllocationPlan

    /// Credit-limit-increase **readiness checklist**. Not a
    /// recommendation to request an increase — the surface stays in
    /// "ready to review" / "needs more evidence" language so users
    /// approach their issuer with evidence, not promises.
    let limitReadiness: CreditLimitReadinessChecklist

    /// Recent spending context derived from the deterministic
    /// `SpendingTrendSummary`. **Context only** — never modifies the
    /// paydown targets carried in ``paymentAllocation``. `nil` when
    /// the caller didn't supply a trend summary or the summary was
    /// too thin to describe.
    let spendingContext: CreditTimingSpendingContext?

    /// `now` the engine used when evaluating snapshot freshness.
    /// Surfaced so the UI can show an honest "evaluated as of" label
    /// and tests can pin the value.
    let evaluatedAt: Date
}

// MARK: - Derived

extension CreditTimingDecision {

    /// Count of outstanding user-side checks. Feeds the hero's "N
    /// checks remaining" chip the same way Scenario 1 does.
    var outstandingCheckCount: Int {
        missingDataChecklist.count
    }

    /// Number of cards the engine evaluated — total regardless of
    /// ruling. Used by the hero to show "N cards" in accessibility.
    var cardCount: Int {
        cardAssessments.count
    }
}
