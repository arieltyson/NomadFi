// SpendAnomalyKind.swift
// NomadFi
//
// Named kinds of transaction anomaly the detector surfaces. Kept
// deliberately narrow — NomadFi ships exactly two signals in this
// slice, both grounded in the `RecurringChargeDetector`'s baseline:
//
//   • `.missingRecurringCharge` — a recurring charge NomadFi
//     normally sees at this cadence has not appeared inside a
//     conservative window after the expected date.
//   • `.amountSpike` — the latest matching charge on an otherwise
//     recurring merchant is materially higher than the baseline
//     of prior charges.
//
// Never framed as fraud, a billing error, or a guaranteed outcome.
// These are "worth reviewing" surfaces, full stop.

import Foundation

/// What kind of anomaly the detector found.
enum SpendAnomalyKind: String, Sendable, Equatable, CaseIterable {

    /// A recurring charge that should have landed by now based on
    /// its usual cadence has not appeared in the user's history
    /// within a conservative grace window.
    case missingRecurringCharge

    /// The latest matching charge on a recurring merchant is
    /// materially higher than the user's own baseline of prior
    /// matching charges.
    case amountSpike

    // MARK: - Display

    /// Short title used on the `FinancialInsight` card. Never
    /// claims fraud, a billing error, or a guaranteed outcome.
    var displayTitle: String {
        switch self {
        case .missingRecurringCharge: "Recurring charge is missing"
        case .amountSpike: "Recurring charge is higher than usual"
        }
    }

    /// The card title, naming the merchant so each card says something
    /// different at a glance.
    func insightTitle(merchant: String) -> String {
        switch self {
        case .missingRecurringCharge: "\(merchant) hasn't charged"
        case .amountSpike: "\(merchant) cost more than usual"
        }
    }

    /// VoiceOver phrasing.
    var accessibilityLabel: String {
        switch self {
        case .missingRecurringCharge:
            "Recurring charge appears to be missing. Worth reviewing in your history."
        case .amountSpike:
            "Recurring charge is higher than the user's own baseline. Worth reviewing."
        }
    }

    /// SF Symbol paired with the title so Differentiate-Without-
    /// Color users read the kind correctly.
    var systemImage: String {
        switch self {
        case .missingRecurringCharge: "clock.arrow.circlepath"
        case .amountSpike: "chart.line.uptrend.xyaxis"
        }
    }
}
