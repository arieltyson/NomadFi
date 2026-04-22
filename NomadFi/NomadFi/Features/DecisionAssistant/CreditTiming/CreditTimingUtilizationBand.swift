// CreditTimingUtilizationBand.swift
// NomadFi
//
// Named bands for credit-utilization ratios. NomadFi never claims a
// single utilization value will change a credit score — myFICO's own
// "Amounts owed" guidance warns against that. The bands exist solely
// to translate a ratio into calm, non-promissory UI copy ("elevated",
// "near limit") rather than a raw percentage the user is left to
// interpret alone.

import Foundation

/// Named buckets for the `currentBalance / creditLimit` ratio on a
/// credit card. Ranges are half-open so the transitions land on round
/// percentages the UI can show without rounding drama.
///
/// Intentionally separate from any colour mapping: the status badge
/// colour lives on the UI side; this enum stays SwiftUI-free so the
/// engine and tests can reason about bands without importing SwiftUI.
enum CreditTimingUtilizationBand: String, Sendable, Equatable, CaseIterable {

    /// Utilization < 10%. NomadFi never calls this "safe" or "healthy".
    case low

    /// 10% ≤ utilization < 30%. The conservative CFPB-style planning
    /// target is below 30%; this band means the user is already there.
    case planning

    /// 30% ≤ utilization < 60%. Above the conservative threshold — the
    /// engine recommends paying down before statement close.
    case elevated

    /// 60% ≤ utilization < 90%. The reported balance would be a large
    /// share of the limit; the engine recommends a firmer pay-down.
    case high

    /// Utilization ≥ 90%. Avoid additional purchases on this card
    /// until the balance comes down.
    case nearLimit

    // MARK: - Mapping

    /// Maps a raw fraction into a band. A non-positive limit or a
    /// negative balance should never reach here; callers must pre-check
    /// inputs, so this function assumes a well-formed ratio.
    static func band(for ratio: Double) -> CreditTimingUtilizationBand {
        switch ratio {
        case ..<0.10: .low
        case 0.10..<0.30: .planning
        case 0.30..<0.60: .elevated
        case 0.60..<0.90: .high
        default: .nearLimit
        }
    }

    // MARK: - Display

    /// Short, non-promissory label. Never uses "safe", "good", or any
    /// wording that implies a guaranteed credit-score outcome.
    var displayLabel: String {
        switch self {
        case .low: "Low use"
        case .planning: "Planning target"
        case .elevated: "Elevated"
        case .high: "High"
        case .nearLimit: "Near limit"
        }
    }

    /// VoiceOver phrasing — still non-promissory, still careful to
    /// avoid score-impact language.
    var accessibilityLabel: String {
        switch self {
        case .low: "Low credit use"
        case .planning: "Within a conservative planning target"
        case .elevated: "Elevated credit use"
        case .high: "High credit use"
        case .nearLimit: "Credit use near the limit"
        }
    }
}
