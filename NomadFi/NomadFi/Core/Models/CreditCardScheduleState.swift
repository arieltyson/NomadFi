// CreditCardScheduleState.swift
// NomadFi
//
// Coarse state used by the Settings UI to summarise a credit card's
// statement calendar. Kept UI-framework-free so it can be unit tested
// without importing SwiftUI; colour mapping lives in the view layer.

import Foundation

/// The rendered state of a credit-card schedule in Settings.
///
/// States are derived from whichever subset of schedule dates have
/// been entered, plus whether the user has recently confirmed them.
enum CreditCardScheduleState: Sendable, Equatable, CaseIterable {

    /// No schedule dates have been entered yet.
    case missing

    /// Some but not all of the three core dates are entered.
    case partial

    /// All three core dates are entered, ordered correctly, and the
    /// user has marked the schedule as confirmed.
    case confirmed

    /// All three dates are entered but their ordering is not
    /// meaningful (e.g. the payment due date is before the statement
    /// closing date). Requires the user's attention before it can be
    /// relied on elsewhere in the app.
    case needsAttention

    /// Short, user-facing label suitable for a ``StatusBadge``.
    var displayLabel: String {
        switch self {
        case .missing: "Missing"
        case .partial: "Partial"
        case .confirmed: "Confirmed"
        case .needsAttention: "Check dates"
        }
    }

    /// SF Symbol used alongside ``displayLabel``. Paired so the state
    /// reads correctly even with Differentiate Without Color enabled.
    var systemImage: String {
        switch self {
        case .missing: "questionmark.circle"
        case .partial: "minus.circle"
        case .confirmed: "checkmark.seal"
        case .needsAttention: "exclamationmark.triangle"
        }
    }
}
