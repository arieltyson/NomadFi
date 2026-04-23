// PurchaseCandidateStance.swift
// NomadFi
//
// Per-account stance produced by the generic purchase engine.
// Never promissory — every case describes the most honest thing
// NomadFi can say given the data on file.

import Foundation

/// Where a single account sits in the engine's ranking.
enum PurchaseCandidateStance: String, Sendable, Equatable, CaseIterable {

    /// The engine's first pick for this purchase.
    case recommended

    /// Usable second choice if the primary is unavailable.
    case fallback

    /// Clears the hard guardrails but is not picked — either a
    /// stronger candidate exists or the caveats (FX, utilization,
    /// unconfirmed schedule) are enough to keep NomadFi from
    /// promoting it.
    case usableWithCaveats

    /// Deposit, wallet, or savings account where the known balance
    /// is below the purchase amount in the matching currency.
    case insufficientFunds

    /// Credit card whose known available credit (or
    /// `limit - currentBalance`) cannot cover the purchase.
    case insufficientCreditCoverage

    /// Snapshot is older than the freshness window for its source.
    case snapshotStale

    /// Missing profile data — credit card without `creditLimit`
    /// or `currentBalance`, or a deposit account with neither a
    /// snapshot nor a legacy balance.
    case needsSetup

    /// Investment account. Never a payment method in NomadFi.
    case excludedInvestment

    // MARK: - Display

    var displayLabel: String {
        switch self {
        case .recommended: "Recommended"
        case .fallback: "Fallback"
        case .usableWithCaveats: "Usable with caveats"
        case .insufficientFunds: "Insufficient funds"
        case .insufficientCreditCoverage: "Insufficient credit coverage"
        case .snapshotStale: "Snapshot stale"
        case .needsSetup: "Needs setup"
        case .excludedInvestment: "Investment excluded"
        }
    }

    var systemImage: String {
        switch self {
        case .recommended: "checkmark.seal.fill"
        case .fallback: "arrow.triangle.branch"
        case .usableWithCaveats: "exclamationmark.circle"
        case .insufficientFunds: "xmark.circle"
        case .insufficientCreditCoverage: "creditcard.trianglebadge.exclamationmark"
        case .snapshotStale: "clock.badge.exclamationmark"
        case .needsSetup: "questionmark.circle"
        case .excludedInvestment: "nosign"
        }
    }

    /// VoiceOver phrasing — longer and non-promissory.
    var accessibilityLabel: String {
        switch self {
        case .recommended:
            "Recommended for this purchase based on saved account data."
        case .fallback:
            "Usable fallback if the recommended account isn't available."
        case .usableWithCaveats:
            "Usable, but NomadFi is not promoting it because of open caveats."
        case .insufficientFunds:
            "Known balance is below the purchase amount."
        case .insufficientCreditCoverage:
            "Credit card available credit is below the purchase amount."
        case .snapshotStale:
            "Latest balance snapshot is stale. No strong recommendation."
        case .needsSetup:
            "Account profile or snapshot is missing. No strong recommendation."
        case .excludedInvestment:
            "Investment account. NomadFi does not treat it as a payment method."
        }
    }

    /// Whether the engine considers this stance a usable payment
    /// method (either primary, fallback, or caveated).
    var isUsable: Bool {
        switch self {
        case .recommended, .fallback, .usableWithCaveats:
            true
        case .insufficientFunds,
             .insufficientCreditCoverage,
             .snapshotStale,
             .needsSetup,
             .excludedInvestment:
            false
        }
    }
}
