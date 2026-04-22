// CreditTimingCardRuling.swift
// NomadFi
//
// Per-card ruling for the Credit Timing engine. Every value is
// intentionally conservative — NomadFi never promises a credit-score
// increase, never recommends carrying a balance, and never pretends a
// snapshot from last month is a live balance.

import Foundation

/// Deterministic ruling for a single credit card in the Credit Timing
/// engine. Each case describes the most honest thing NomadFi can say
/// given the evidence on file.
enum CreditTimingCardRuling: String, Sendable, Equatable, CaseIterable {

    /// Profile data is incomplete — typically a missing `creditLimit`
    /// or `currentBalance`. NomadFi refuses to reason about utilization
    /// without both values.
    case needsSetup

    /// The most recent snapshot is older than its source's freshness
    /// window. The engine does not issue a strong recommendation from
    /// a stale number.
    case snapshotStale

    /// The statement calendar (`statementPeriodStart`, `statementClose`,
    /// `paymentDue`) is not fully confirmed. Without a confirmed close
    /// date the engine cannot anchor paydown guidance to a real date.
    case scheduleMissing

    /// Utilization is within the low / planning bands and the data is
    /// fresh. No urgent action suggested.
    case readyNoUrgentAction

    /// Utilization is in the elevated or high band. Paying the balance
    /// down before the statement closes is suggested; paying the
    /// statement balance in full by the due date remains the hard rule.
    case payDownBeforeClose

    /// Utilization is at or near the credit limit. The engine
    /// recommends avoiding additional spend on this card until the
    /// balance comes down.
    case nearLimitAvoidMoreSpend

    // MARK: - Display

    /// Short title surfaced in per-card rows.
    var displayLabel: String {
        switch self {
        case .needsSetup: "Needs setup"
        case .snapshotStale: "Snapshot stale"
        case .scheduleMissing: "Schedule missing"
        case .readyNoUrgentAction: "Ready"
        case .payDownBeforeClose: "Pay down before close"
        case .nearLimitAvoidMoreSpend: "Near limit"
        }
    }

    /// SF Symbol for the row badge; pairs with the label so
    /// Differentiate-Without-Color users still read the ruling
    /// correctly.
    var systemImage: String {
        switch self {
        case .needsSetup: "questionmark.circle"
        case .snapshotStale: "clock.badge.exclamationmark"
        case .scheduleMissing: "calendar.badge.exclamationmark"
        case .readyNoUrgentAction: "checkmark.seal"
        case .payDownBeforeClose: "arrow.down.circle"
        case .nearLimitAvoidMoreSpend: "exclamationmark.triangle"
        }
    }

    /// VoiceOver phrasing that never promises an outcome.
    var accessibilityLabel: String {
        switch self {
        case .needsSetup:
            "Card needs setup. Credit limit or current balance is not on file."
        case .snapshotStale:
            "Latest balance snapshot is stale. No strong recommendation until the user refreshes it."
        case .scheduleMissing:
            "Statement calendar is not confirmed. No strong recommendation until it is."
        case .readyNoUrgentAction:
            "Card is within a conservative planning target. No urgent action."
        case .payDownBeforeClose:
            "Consider paying the balance down before the statement closes."
        case .nearLimitAvoidMoreSpend:
            "Card is near its limit. Avoid additional spend until the balance comes down."
        }
    }
}
