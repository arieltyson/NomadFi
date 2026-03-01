// SubscriptionDetector.swift
// NomadFi
//
// Detects recurring subscriptions by pattern-matching transactions
// on merchant name, amount, and regular billing intervals.

import Foundation
import OSLog

/// Detects recurring subscriptions by analyzing transaction patterns.
///
/// Looks for repeated charges from the same merchant at consistent amounts
/// and regular intervals (weekly, monthly, quarterly, or annual). This is
/// a pure-function engine — no side effects, fully testable.
///
/// - Note: Processes transactions on the main actor because SwiftData
///   `@Model` objects are main-actor isolated.
enum SubscriptionDetector {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "SubscriptionDetector")

    /// A detected subscription candidate before user confirmation.
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
    /// Groups transactions by normalized merchant name and consistent amount,
    /// then checks for regular billing intervals.
    ///
    /// - Parameter transactions: All user transactions to analyze.
    /// - Returns: Detected subscription candidates sorted by confidence.
    @MainActor
    static func detect(from transactions: [Transaction]) -> [DetectedSubscription] {
        // Group by normalized merchant name
        let grouped = Dictionary(grouping: transactions) { normalizedMerchant($0.merchantName) }

        var detections: [DetectedSubscription] = []

        for (_, merchantTransactions) in grouped {
            // Sub-group by approximate amount (±5% tolerance for FX fluctuation)
            let amountGroups = groupByAmount(merchantTransactions)

            for group in amountGroups where group.count >= 2 {
                if let detected = analyzePattern(group) {
                    detections.append(detected)
                }
            }
        }

        let sorted = detections.sorted { $0.confidence > $1.confidence }
        logger.info("Detected \(sorted.count) potential subscriptions from \(transactions.count) transactions")
        return sorted
    }

    /// Checks whether a subscription already exists in the persisted records.
    @MainActor
    static func isAlreadyTracked(
        _ detection: DetectedSubscription,
        existing: [Subscription]
    ) -> Bool {
        existing.contains { subscription in
            normalizedMerchant(subscription.serviceName) == normalizedMerchant(detection.merchantName)
                && abs(subscription.amount - detection.amount) < detection.amount * 0.05
        }
    }

    // MARK: - Pattern Analysis

    private static func analyzePattern(_ transactions: [Transaction]) -> DetectedSubscription? {
        guard transactions.count >= 2 else { return nil }

        let sorted = transactions.sorted { $0.date < $1.date }
        let intervals = calculateIntervals(sorted)

        guard let frequency = detectFrequency(intervals) else { return nil }

        let representativeTransaction = sorted.last!
        let nextDate = estimateNextDate(
            from: representativeTransaction.date,
            frequency: frequency
        )

        let confidence: Confidence = switch transactions.count {
        case 4...: .high
        case 3: .high
        case 2: intervals.allSatisfy({ isReasonableInterval($0) }) ? .medium : .low
        default: .low
        }

        return DetectedSubscription(
            merchantName: representativeTransaction.merchantName,
            amount: abs(representativeTransaction.originalAmount),
            currencyCode: representativeTransaction.originalCurrency ?? .usd,
            frequency: frequency,
            jurisdiction: representativeTransaction.jurisdiction,
            nextEstimatedDate: nextDate,
            matchedTransactionCount: transactions.count,
            confidence: confidence
        )
    }

    // MARK: - Interval Calculation

    private static func calculateIntervals(_ sortedTransactions: [Transaction]) -> [TimeInterval] {
        guard sortedTransactions.count >= 2 else { return [] }

        var intervals: [TimeInterval] = []
        for i in 1..<sortedTransactions.count {
            let interval = sortedTransactions[i].date.timeIntervalSince(sortedTransactions[i - 1].date)
            intervals.append(interval)
        }
        return intervals
    }

    private static func detectFrequency(_ intervals: [TimeInterval]) -> BillingFrequency? {
        guard !intervals.isEmpty else { return nil }

        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let days = averageInterval / 86400

        // Match to closest billing frequency with tolerance
        if isApproximatelyEqual(days, to: 7, tolerance: 2) {
            return .weekly
        } else if isApproximatelyEqual(days, to: 30, tolerance: 5) {
            return .monthly
        } else if isApproximatelyEqual(days, to: 90, tolerance: 10) {
            return .quarterly
        } else if isApproximatelyEqual(days, to: 365, tolerance: 30) {
            return .annual
        }

        return nil
    }

    private static func estimateNextDate(from lastDate: Date, frequency: BillingFrequency) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: lastDate) ?? lastDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: lastDate) ?? lastDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: lastDate) ?? lastDate
        case .annual:
            return calendar.date(byAdding: .year, value: 1, to: lastDate) ?? lastDate
        }
    }

    // MARK: - Grouping Helpers

    @MainActor
    private static func groupByAmount(_ transactions: [Transaction]) -> [[Transaction]] {
        var groups: [[Transaction]] = []

        for transaction in transactions {
            let amount = abs(transaction.originalAmount)
            if let groupIndex = groups.firstIndex(where: { group in
                guard let representative = group.first else { return false }
                let representativeAmount = abs(representative.originalAmount)
                return abs(amount - representativeAmount) < representativeAmount * 0.05
            }) {
                groups[groupIndex].append(transaction)
            } else {
                groups.append([transaction])
            }
        }

        return groups
    }

    // MARK: - String & Number Helpers

    private static func normalizedMerchant(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacing(#/\s+/#, with: " ")
    }

    private static func isApproximatelyEqual(_ value: Double, to target: Double, tolerance: Double) -> Bool {
        abs(value - target) <= tolerance
    }

    private static func isReasonableInterval(_ interval: TimeInterval) -> Bool {
        let days = interval / 86400
        return days >= 5 && days <= 400  // Between weekly and annual
    }
}
