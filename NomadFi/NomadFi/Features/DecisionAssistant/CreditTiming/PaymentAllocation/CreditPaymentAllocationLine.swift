// CreditPaymentAllocationLine.swift
// NomadFi
//
// A single card's row in the payment-allocation plan. Derived purely
// from the engine's per-card assessment — never from SwiftData — so
// the view layer and tests can consume it without a main-actor hop.

import Foundation

/// Recommended paydown amounts for one card, plus the priority the
/// planner assigned. If the planner was given a user-entered budget,
/// `suggestedPayment` is filled in for cards whose currency matches
/// the budget; otherwise it stays `nil` and the UI shows only the
/// target amounts.
struct CreditPaymentAllocationLine: Sendable, Equatable, Identifiable {

    /// Stable identity — carried through from the assessment so the
    /// UI can diff rows safely.
    let id: String

    let accountName: String
    let institutionName: String
    let currencyCode: String

    /// Zero-based rank among eligible cards inside its currency
    /// group. 0 = highest priority.
    let priority: Int

    /// Ruling the engine already assigned — kept here so the card
    /// row can explain *why* this line is in the plan.
    let ruling: CreditTimingCardRuling

    /// Current utilization fraction when computable.
    let utilization: Double?

    /// Paydown needed to land ≈30 % utilization. `nil` when the card
    /// is already below the threshold or inputs are missing.
    let paydownToConservativeTarget: Double?

    /// Optional stronger paydown to land ≈10 % utilization. `nil` for
    /// the same reasons.
    let paydownToStrongTarget: Double?

    /// Planner's distribution of the user-supplied budget to this
    /// line. `nil` when no budget was passed, or when the budget's
    /// currency doesn't match this line. Never exceeds the
    /// conservative target without the strong target also being
    /// covered for every higher-priority line first.
    let suggestedPayment: Double?

    /// Statement close for this card when the schedule is confirmed.
    let statementClosingDate: Date?

    /// One-sentence reason the planner put this card at this
    /// priority slot. Never promissory.
    let reason: String
}
