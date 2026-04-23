// CreditTimingSpendingDirection.swift
// NomadFi
//
// Named direction for the latest month's spend compared against a
// prior baseline. Deterministic — computed from magnitudes only,
// never from a trend line. NomadFi never says the user *will* spend
// the same amount again or predicts a credit-score change.

import Foundation

/// Direction of the latest month's spend relative to the prior
/// comparison baseline. The Credit Timing brief renders a single
/// sentence off this enum; it is intentionally coarse so the copy
/// stays calm and honest.
enum CreditTimingSpendingDirection: String, Sendable, Equatable, CaseIterable {

    /// Latest month is at least 5 % higher than the baseline.
    case rising

    /// Latest month is at least 5 % lower than the baseline.
    case falling

    /// Latest month is within ±5 % of the baseline.
    case steady

    /// Fewer than two months of data — not enough signal to compare.
    case insufficient

    // MARK: - Display

    /// Short one-line caption for the brief. Never implies the user
    /// *will* repeat the pattern, never references a credit score.
    var displaySummary: String {
        switch self {
        case .rising:
            "Trend is climbing compared with the prior comparison baseline."
        case .falling:
            "Trend is cooling compared with the prior comparison baseline."
        case .steady:
            "Trend is holding steady compared with the prior comparison baseline."
        case .insufficient:
            "Not enough months of tracked spend yet to compare."
        }
    }

    /// VoiceOver phrasing. Same non-promissory rules apply.
    var accessibilityLabel: String {
        switch self {
        case .rising:
            "Recent tracked spend is climbing compared with the prior comparison baseline."
        case .falling:
            "Recent tracked spend is cooling compared with the prior comparison baseline."
        case .steady:
            "Recent tracked spend is holding steady compared with the prior comparison baseline."
        case .insufficient:
            "NomadFi does not have enough tracked spend yet to compare months."
        }
    }

    /// SF Symbol paired with the caption so Differentiate-Without-
    /// Color users still read the direction.
    var systemImage: String {
        switch self {
        case .rising: "arrow.up.right"
        case .falling: "arrow.down.right"
        case .steady: "equal"
        case .insufficient: "questionmark.circle"
        }
    }
}
