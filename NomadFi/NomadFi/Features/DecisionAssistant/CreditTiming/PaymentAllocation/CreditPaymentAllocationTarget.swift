// CreditPaymentAllocationTarget.swift
// NomadFi
//
// Named utilization target a plan line is trying to hit. Exists so
// the UI and tests can reason about whether a line is a conservative
// "under 30%" step or the stronger "under 10%" optional step,
// without reaching into the engine's threshold constants.

import Foundation

/// Utilization target an allocation line is aimed at.
///
/// The raw percentages stay anchored to the engine's existing
/// `CreditTimingDecisionEngine.conservativePlanningThreshold` and
/// `.strongPlanningThreshold` — this enum is a semantic label, not a
/// second source of truth.
enum CreditPaymentAllocationTarget: String, Sendable, Equatable, CaseIterable {

    /// Paydown amount to land roughly at or below the conservative
    /// 30 % utilization target by statement close.
    case conservativeThirtyPercent

    /// Optional stronger paydown to land roughly at or below 10 %.
    /// NomadFi never claims hitting this target changes a credit
    /// score; it's offered as a calmer planning option.
    case strongTenPercent

    // MARK: - Display

    /// Short label for card metrics.
    var displayLabel: String {
        switch self {
        case .conservativeThirtyPercent: "30% target"
        case .strongTenPercent: "10% target (optional)"
        }
    }

    /// VoiceOver phrasing. Never promises a score outcome.
    var accessibilityLabel: String {
        switch self {
        case .conservativeThirtyPercent:
            "Paydown amount to reach a conservative thirty percent utilization target before statement close."
        case .strongTenPercent:
            "Optional paydown amount to reach a stronger ten percent utilization target. NomadFi does not predict credit score outcomes."
        }
    }
}
