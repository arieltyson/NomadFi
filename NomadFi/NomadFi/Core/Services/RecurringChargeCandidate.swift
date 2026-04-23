// RecurringChargeCandidate.swift
// NomadFi
//
// Value type produced by `RecurringChargeDetector` when it sees a
// repeating charge pattern across a user's `Transaction` rows.
// Carries only the fields callers need for clustering, display, and
// UI caveats — never the underlying SwiftData objects. Keeping this
// pure lets engines, views, and tests consume the output without
// a main-actor hop.

import Foundation

/// Strength of the detector's signal. Ordered so
/// `candidates.sorted(by:) { $0.confidence > $1.confidence }` works
/// without custom comparators.
enum RecurringChargeConfidence: Int, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: RecurringChargeConfidence, rhs: RecurringChargeConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single recurring-charge pattern detected on a transaction
/// stream. Immutable — re-run detection to refresh.
struct RecurringChargeCandidate: Sendable, Equatable, Identifiable {

    /// Stable identifier derived from the normalized merchant key,
    /// representative amount (rounded to two decimals), and currency.
    /// Same inputs → same id across runs, so UIs can diff safely.
    let id: String

    /// Cleaned merchant string suitable for a list header — comes
    /// straight from the representative (most-recent) transaction's
    /// `merchantName` so the user sees the casing they recognise.
    let displayMerchantName: String

    /// Deterministic normalization key (uppercase, processor prefixes
    /// stripped) produced by `MerchantNormalizer`. Useful to dedupe
    /// against other detector outputs without re-running the
    /// normalizer.
    let normalizedMerchantKey: String

    /// Positive magnitude of a single recurring charge in the
    /// transaction's original currency. Always `abs(...)` — sign
    /// conventions vary by import profile.
    let representativeAmount: Double

    let currencyCode: CurrencyCode

    /// Cadence chosen from the closest named bucket. Nil frequencies
    /// are never surfaced — if the detector can't bucket an interval,
    /// it drops the group.
    let frequency: BillingFrequency

    let confidence: RecurringChargeConfidence

    /// Number of charges that matched the pattern. Two is the minimum
    /// the detector will accept.
    let matchedTransactionCount: Int

    /// Date of the most recent matching charge.
    let lastChargeDate: Date

    /// Projection of the next expected charge based on `frequency`
    /// added to `lastChargeDate`. This is a calendar projection, not
    /// a guarantee — the engine never claims the charge *will* hit.
    let nextEstimatedDate: Date

    /// Category carried over from the representative transaction's
    /// own categorisation (which itself came from either manual
    /// entry or the deterministic keyword inferrer). Useful for
    /// grouping on the UI side.
    let category: TransactionCategory

    /// Jurisdiction carried over from the representative transaction,
    /// so downstream cross-border comparisons can still run.
    let jurisdiction: String
}
