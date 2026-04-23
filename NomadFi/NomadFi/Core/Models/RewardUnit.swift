// RewardUnit.swift
// NomadFi
//
// Pure, Codable enum describing how a credit card's reward rate is
// denominated. Kept SwiftUI- and AppIntents-free so the engine, the
// persistence layer, and the settings UI can all consume it without
// framework dependencies.

import Foundation

/// Denomination of a credit-card reward rate. The engine never
/// converts between units — if two candidates use different units,
/// rewards stop being a ranker and become context only.
enum RewardUnit: String, Codable, CaseIterable, Sendable, Hashable {

    /// Rate expressed as a percent of the purchase amount, returned
    /// as statement credit / cash back.
    case cashBackPercent

    /// Rate expressed as program points per dollar of purchase.
    case pointsPerDollar

    /// Rate expressed as miles per dollar of purchase.
    case milesPerDollar

    /// Unit is not recorded yet. Engine treats this as "no reward
    /// signal" even when a numeric rate is present.
    case unknown

    // MARK: - Display

    /// Short label suitable for pickers and status badges.
    var displayLabel: String {
        switch self {
        case .cashBackPercent: "Cash back %"
        case .pointsPerDollar: "Points per dollar"
        case .milesPerDollar: "Miles per dollar"
        case .unknown: "Unit unknown"
        }
    }

    /// Longer VoiceOver / description string.
    var accessibilityLabel: String {
        switch self {
        case .cashBackPercent: "Cash back percent"
        case .pointsPerDollar: "Points earned per dollar"
        case .milesPerDollar: "Miles earned per dollar"
        case .unknown: "Reward unit not recorded"
        }
    }

    /// Suffix the spoken / printed rate should carry — for example
    /// "1.5%" vs. "1.5 points per dollar". `nil` for `.unknown` so
    /// callers never manufacture a label for data they can't trust.
    var valueSuffix: String? {
        switch self {
        case .cashBackPercent: "%"
        case .pointsPerDollar: " points per dollar"
        case .milesPerDollar: " miles per dollar"
        case .unknown: nil
        }
    }
}

// MARK: - Raw-value bridge

extension RewardUnit {

    /// Safe mapping from a persisted raw value to the typed unit.
    /// Unknown raw strings fall back to ``unknown`` — never crash.
    static func fromRawValue(_ raw: String?) -> RewardUnit {
        guard let raw, let unit = RewardUnit(rawValue: raw) else {
            return .unknown
        }
        return unit
    }
}
