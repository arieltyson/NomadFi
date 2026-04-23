// SpendAnomaly.swift
// NomadFi
//
// Pure value type the Dashboard's `InsightEngine` consumes when
// rendering an anomaly card. Carries enough to build a calm,
// honest one-line explanation without reaching back into SwiftData.

import Foundation

/// A single anomaly detected against the user's own transaction
/// history. Never claims the charge is wrong or fraudulent —
/// consumers should treat it as a "worth reviewing" hint.
struct SpendAnomaly: Sendable, Equatable, Identifiable {

    /// Stable identifier: merchant key + kind + ISO date of the
    /// expected or observed charge. Same inputs → same id across
    /// runs, so UIs can diff safely.
    let id: String

    let kind: SpendAnomalyKind

    /// Merchant string the UI shows — copied from the underlying
    /// `RecurringChargeCandidate.displayMerchantName`.
    let displayMerchantName: String

    /// Deterministic normalization key produced by
    /// `MerchantNormalizer`. Useful when a caller needs to match
    /// the anomaly back to the candidate without re-normalising.
    let normalizedMerchantKey: String

    let currencyCode: CurrencyCode

    /// Cadence the underlying recurring candidate established
    /// (weekly / monthly / quarterly / annual).
    let frequency: BillingFrequency

    /// Magnitude the user has historically paid at this cadence —
    /// i.e. the baseline the anomaly is being compared against.
    /// For spikes this is the mean of prior matching charges; for
    /// missing charges this is the representative amount.
    let baselineAmount: Double

    /// The actual latest charge for this merchant when applicable.
    /// `nil` for missing-charge anomalies — there isn't one.
    let observedAmount: Double?

    /// Most recent matching charge on file for this merchant. For
    /// missing anomalies this is the prior cadence anchor.
    let lastChargeDate: Date

    /// Expected next charge date projected off the cadence. Only
    /// meaningful for missing anomalies; equal to `lastChargeDate`
    /// for spikes.
    let expectedDate: Date?

    /// Number of prior matching charges the detector used to
    /// establish the baseline. Surfaced so callers can cite "based
    /// on 4 prior monthly charges" honestly.
    let historyCount: Int

    /// Short, calm explanation suitable for the insight card. The
    /// anomaly detector curates this so tests can sweep the entire
    /// surface for banned vocabulary.
    let explanation: String
}
