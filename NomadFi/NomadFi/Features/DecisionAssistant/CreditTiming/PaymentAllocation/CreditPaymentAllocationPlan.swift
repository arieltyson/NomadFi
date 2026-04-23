// CreditPaymentAllocationPlan.swift
// NomadFi
//
// Portfolio-wide payment-allocation plan. The planner never mixes
// currencies — each group is independent — so the user can see what
// a payment in each currency would cover without NomadFi inventing
// an FX rate.

import Foundation

/// Optional budget the user can ask the planner to distribute.
/// Kept on the value layer so it's trivially testable and never
/// persisted — the brief view owns transient state only.
struct CreditPaymentAllocationBudget: Sendable, Equatable {
    let amount: Double
    let currencyCode: String
}

/// One currency's worth of plan lines. Totals are pre-computed so
/// the UI doesn't re-reduce for each Dynamic Type pass.
struct CreditPaymentAllocationCurrencyGroup: Sendable, Equatable, Identifiable {
    var id: String { currencyCode }

    let currencyCode: String

    /// Plan lines inside this currency, already sorted by priority.
    let lines: [CreditPaymentAllocationLine]

    /// Sum of ``CreditPaymentAllocationLine/paydownToConservativeTarget``
    /// across the group — treating nil as zero.
    let totalPaydownToConservativeTarget: Double

    /// Sum of ``CreditPaymentAllocationLine/paydownToStrongTarget``
    /// across the group — treating nil as zero.
    let totalPaydownToStrongTarget: Double

    /// Sum of ``CreditPaymentAllocationLine/suggestedPayment`` when a
    /// matching-currency budget was supplied. Zero otherwise.
    let suggestedTotalPayment: Double
}

/// Full portfolio plan. Tests pin every field.
struct CreditPaymentAllocationPlan: Sendable, Equatable {

    /// Plan lines grouped by currency. Never empty when at least one
    /// card was eligible — empty when every card is blocked.
    let groups: [CreditPaymentAllocationCurrencyGroup]

    /// Cards excluded from the plan, with their reason. Surfaced in
    /// the UI so the user has something to act on.
    let blockers: [CreditPaymentAllocationBlocker]

    /// Echo of the budget the planner was given. Nil when no budget
    /// was supplied — the plan is then a target sheet.
    let appliedBudget: CreditPaymentAllocationBudget?

    /// Evaluation moment the engine injected.
    let evaluatedAt: Date

    // MARK: - Derived

    /// True when plan lines span more than one currency. The UI uses
    /// this to show the "NomadFi does not convert across currencies
    /// without verified rates" caveat.
    var isMultiCurrency: Bool {
        groups.count > 1
    }

    /// Total eligible plan lines across all currencies.
    var planLineCount: Int {
        groups.reduce(0) { $0 + $1.lines.count }
    }

    /// True when nothing is blocking the plan from being fully
    /// actionable. Useful for the hero chip.
    var isFullyActionable: Bool {
        !groups.isEmpty && blockers.isEmpty
    }
}
