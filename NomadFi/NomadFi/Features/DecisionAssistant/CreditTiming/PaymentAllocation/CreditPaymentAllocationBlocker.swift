// CreditPaymentAllocationBlocker.swift
// NomadFi
//
// A card the planner deliberately excluded from strong allocation.
// Surfaces in the UI so the user sees *why* their card isn't in the
// plan rather than silently disappearing.

import Foundation

/// Reason a card was excluded from allocation.
enum CreditPaymentAllocationBlockerReason: String, Sendable, Equatable, CaseIterable {
    case missingCreditLimit
    case missingBalanceSnapshot
    case staleSnapshot
    case unconfirmedSchedule
    case belowConservativeTarget

    /// Short, user-actionable explanation. Never promissory.
    var displayLabel: String {
        switch self {
        case .missingCreditLimit:
            "Credit limit is not on file yet."
        case .missingBalanceSnapshot:
            "No current-balance snapshot on file yet."
        case .staleSnapshot:
            "Latest balance snapshot is past its freshness window."
        case .unconfirmedSchedule:
            "Statement calendar is not fully confirmed."
        case .belowConservativeTarget:
            "Already below the conservative 30% utilization target."
        }
    }

    /// VoiceOver phrasing.
    var accessibilityLabel: String {
        "Excluded from the payment plan: \(displayLabel)"
    }
}

/// A card excluded from the allocation plan. The view renders these
/// as a "why not planned" list so the user can fix the underlying
/// data and re-run.
struct CreditPaymentAllocationBlocker: Sendable, Equatable, Identifiable {
    let id: String
    let accountName: String
    let institutionName: String
    let reason: CreditPaymentAllocationBlockerReason
}
