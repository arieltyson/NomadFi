// RewardRateEvaluation.swift
// NomadFi
//
// Pure value type the purchase engine uses when it evaluates a
// single account's reward terms against a specific purchase. Carries
// both the structural facts (rate, unit, source) and the engine's
// decision about whether this reward signal is trustworthy enough to
// factor into ranking.

import Foundation

/// Result of evaluating a ``RewardProfile`` for a given
/// ``MerchantCategory`` and `now` timestamp.
struct RewardRateEvaluation: Sendable, Equatable {

    /// The effective rate NomadFi would quote to the user —
    /// category override when one exists, otherwise the base rate.
    /// `nil` when the user has not recorded any rate.
    let rate: Double?

    /// Unit the rate is denominated in.
    let unit: RewardUnit

    /// Official-source confidence after freshness gating. Mirrors
    /// the pattern ``SourceFreshness/effectiveConfidence(for:domain:now:)``
    /// already uses for FX fees.
    let effectiveConfidence: SourceConfidence

    /// Whether the source was verified *and* still inside the
    /// issuer-terms freshness window. The engine only factors
    /// rewards into ranking when this is `true`.
    let isVerifiedAndFresh: Bool

    /// Whether a category-specific override drove this rate. Used
    /// by the brief sheet / voice copy to explain why a specific
    /// number is being quoted.
    let categoryOverrideApplied: Bool

    /// Human-readable snippet for the brief sheet / VoiceOver read.
    /// Never appears in the spoken recommendation unless
    /// ``isVerifiedAndFresh`` is `true`.
    let explanation: String?

    // MARK: - Derived

    /// True when the engine has a numeric rate that is also verified
    /// + fresh, i.e. safe to use for ranking.
    var isUsableForRanking: Bool {
        guard let rate, rate > 0 else { return false }
        guard isVerifiedAndFresh else { return false }
        return unit != .unknown
    }

    /// Produces a short rate label (e.g. `"1.5%"`) for display
    /// surfaces. `nil` when the evaluation carries no numeric rate,
    /// or the unit is unknown (which means NomadFi refuses to
    /// manufacture a label).
    var displayRate: String? {
        guard let rate, let suffix = unit.valueSuffix else { return nil }
        let formatted = rate.formatted(
            .number.precision(.fractionLength(0...2))
        )
        return "\(formatted)\(suffix)"
    }
}

// MARK: - Empty / signal-free evaluation

extension RewardRateEvaluation {

    /// Evaluation produced when the account has no reward terms on
    /// file, the unit is unknown, or the record has never been
    /// fetched. Guarantees the engine has a safe default to consult.
    static let empty = RewardRateEvaluation(
        rate: nil,
        unit: .unknown,
        effectiveConfidence: .unverified,
        isVerifiedAndFresh: false,
        categoryOverrideApplied: false,
        explanation: nil
    )
}
