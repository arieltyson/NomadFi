// SubscriptionDetector.swift
// NomadFi
//
// Subscription-specific adapter on top of the generalised
// `RecurringChargeDetector`. Keeps its historical public surface
// (`DetectedSubscription`, `detect(from:)`, `isAlreadyTracked`) so
// the Subscriptions UI and its tests continue to compile, while the
// actual pattern analysis lives in one shared service. The
// distinction between a "subscription" and any other recurring
// charge is a product one (we show them differently), not an
// analytical one, so both consumers benefit from a single detector.

import Foundation
import OSLog

/// Subscription detection façade. Runs the generalised recurring
/// charge detector and projects each candidate onto the legacy
/// ``DetectedSubscription`` shape the Subscriptions surface expects.
enum SubscriptionDetector {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "SubscriptionDetector"
    )

    /// A detected subscription candidate before user confirmation.
    /// Thin view over ``RecurringChargeCandidate`` so existing
    /// callers keep their field names.
    struct DetectedSubscription: Sendable {
        let merchantName: String
        let amount: Double
        let currencyCode: CurrencyCode
        let frequency: BillingFrequency
        let jurisdiction: String
        let nextEstimatedDate: Date
        let matchedTransactionCount: Int
        let confidence: Confidence
    }

    /// How confident the detector is in the subscription pattern.
    enum Confidence: Sendable, Comparable {
        case high    // 3+ matching transactions at regular intervals
        case medium  // 2 matching transactions at a plausible interval
        case low     // Potential match requiring user confirmation
    }

    // MARK: - Public API

    /// Scans transactions for recurring subscription patterns.
    ///
    /// Delegates to ``RecurringChargeDetector`` for the heavy lifting
    /// so the subscription view and any other recurring-charge
    /// consumer share one source of truth for grouping + cadence.
    ///
    /// - Parameter transactions: All user transactions to analyze.
    /// - Returns: Detected subscription candidates sorted by confidence.
    @MainActor
    static func detect(from transactions: [Transaction]) -> [DetectedSubscription] {
        let candidates = RecurringChargeDetector.detect(from: transactions)
        let projected = candidates.map(projectToSubscription)
        logger.info("Projected \(projected.count) subscription candidates from \(candidates.count) recurring charges")
        return projected
    }

    /// Checks whether a subscription already exists in the persisted records.
    @MainActor
    static func isAlreadyTracked(
        _ detection: DetectedSubscription,
        existing: [Subscription]
    ) -> Bool {
        let detectionKey = MerchantNormalizer.normalize(detection.merchantName)
        guard !detectionKey.isEmpty else { return false }

        return existing.contains { subscription in
            let subscriptionKey = MerchantNormalizer.normalize(subscription.serviceName)
            guard subscriptionKey == detectionKey else { return false }

            // Tolerance matches the detector so FX drift on verified
            // rates doesn't double-track the same service.
            let tolerance = max(detection.amount, 0.01)
                * RecurringChargeDetector.amountTolerancePercent
            return abs(subscription.amount - detection.amount) <= tolerance
        }
    }

    // MARK: - Projection

    private static func projectToSubscription(
        _ candidate: RecurringChargeCandidate
    ) -> DetectedSubscription {
        DetectedSubscription(
            merchantName: candidate.displayMerchantName,
            amount: candidate.representativeAmount,
            currencyCode: candidate.currencyCode,
            frequency: candidate.frequency,
            jurisdiction: candidate.jurisdiction,
            nextEstimatedDate: candidate.nextEstimatedDate,
            matchedTransactionCount: candidate.matchedTransactionCount,
            confidence: confidence(from: candidate.confidence)
        )
    }

    private static func confidence(
        from level: RecurringChargeConfidence
    ) -> Confidence {
        switch level {
        case .high: .high
        case .medium: .medium
        case .low: .low
        }
    }
}
