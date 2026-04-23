// RecurringChargeDetector.swift
// NomadFi
//
// Deterministic recurring-charge detector. Takes any `[Transaction]`
// and returns `RecurringChargeCandidate` values for charges that
// repeat on a recognisable cadence (weekly, monthly, quarterly,
// annual). Has no UI coupling, no network calls, no ML — it is a
// pure tokeniser over amount + date intervals that mirrors the
// invariants `SubscriptionDetector` used to enforce locally.
//
// The subscription flow now delegates into this detector so every
// consumer (existing Subscriptions UI + the Dashboard, upcoming
// engines) sees the same rules. Pin every rule in
// `RecurringChargeDetectorTests.swift`.

import Foundation
import OSLog

/// Pure recurring-charge detector. Call ``detect(from:now:)`` with
/// a slice of transactions and iterate the returned candidates.
enum RecurringChargeDetector {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "RecurringChargeDetector"
    )

    // MARK: - Rule constants (pinned in tests)

    /// Amount tolerance for grouping two charges together — covers
    /// small FX drift and sales-tax jitter. Applied relative to the
    /// representative amount of the group (±5 %).
    static let amountTolerancePercent: Double = 0.05

    /// Interval buckets (days) and their tolerances. Ordered shortest
    /// to longest so weekly beats monthly on ambiguous deltas.
    private static let frequencyBuckets:
        [(frequency: BillingFrequency, expectedDays: Double, toleranceDays: Double)] = [
        (.weekly, 7, 2),
        (.monthly, 30, 5),
        (.quarterly, 90, 10),
        (.annual, 365, 30),
    ]

    // MARK: - Public API

    /// Scans `transactions` for repeating charges.
    ///
    /// - Parameters:
    ///   - transactions: Any set of transactions. The detector ignores
    ///     transfers and income-style categories — those are inflows /
    ///     internal moves, not recurring charges.
    ///   - now: Reference "now" for projecting the next estimated
    ///     date. Tests inject a deterministic value.
    /// - Returns: Candidates sorted by confidence (desc) then
    ///   `lastChargeDate` (desc) so the UI can render the strongest,
    ///   freshest signal first.
    @MainActor
    static func detect(
        from transactions: [Transaction],
        now: Date = .now
    ) -> [RecurringChargeCandidate] {
        let eligible = transactions.filter(isEligible)
        guard eligible.count >= 2 else { return [] }

        // Group by (normalized merchant key, currency). Different
        // currencies are never merged — "Netflix USD" and "Netflix
        // CAD" are two separate subscriptions from NomadFi's POV.
        let grouped = Dictionary(grouping: eligible) { transaction -> GroupKey in
            GroupKey(
                merchantKey: normalizedKey(for: transaction),
                currency: transaction.originalCurrency ?? .usd
            )
        }

        var candidates: [RecurringChargeCandidate] = []

        for (_, group) in grouped {
            // Sub-bucket by amount magnitude within the ±5 % window.
            let amountBuckets = groupByAmount(group)
            for bucket in amountBuckets where bucket.count >= 2 {
                if let candidate = buildCandidate(from: bucket, now: now) {
                    candidates.append(candidate)
                }
            }
        }

        let sorted = candidates.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.lastChargeDate > rhs.lastChargeDate
        }

        logger.info("Detected \(sorted.count) recurring candidates from \(transactions.count) transactions")
        return sorted
    }

    // MARK: - Eligibility

    /// Transfers and income are excluded: they are not recurring
    /// *charges* even when they repeat. Zero-amount rows are also
    /// excluded because they can't form an amount bucket.
    private static func isEligible(_ transaction: Transaction) -> Bool {
        let category = transaction.category ?? .other
        if category == .income || category == .transfer {
            return false
        }
        return transaction.originalAmount != 0
    }

    // MARK: - Pattern analysis

    @MainActor
    private static func buildCandidate(
        from transactions: [Transaction],
        now: Date
    ) -> RecurringChargeCandidate? {
        guard transactions.count >= 2 else { return nil }

        let sorted = transactions.sorted { $0.date < $1.date }
        let intervals = consecutiveDayIntervals(for: sorted)
        guard let frequency = matchFrequency(intervals) else { return nil }

        let representative = sorted.last!
        let representativeAmount = abs(representative.originalAmount)
        let currency = representative.originalCurrency ?? .usd
        let normalizedKey = normalizedKey(for: representative)

        let confidence = confidence(
            matchedCount: sorted.count,
            intervalDays: intervals
        )

        let nextEstimated = estimateNextDate(
            after: representative.date,
            frequency: frequency
        )

        let displayName = representative.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)

        return RecurringChargeCandidate(
            id: stableID(
                merchantKey: normalizedKey,
                amount: representativeAmount,
                currency: currency
            ),
            displayMerchantName: displayName.isEmpty ? representative.merchantName : displayName,
            normalizedMerchantKey: normalizedKey,
            representativeAmount: representativeAmount,
            currencyCode: currency,
            frequency: frequency,
            confidence: confidence,
            matchedTransactionCount: sorted.count,
            lastChargeDate: representative.date,
            nextEstimatedDate: nextEstimated,
            category: representative.category ?? .other,
            jurisdiction: representative.jurisdiction
        )
    }

    private static func consecutiveDayIntervals(
        for sortedTransactions: [Transaction]
    ) -> [Double] {
        guard sortedTransactions.count >= 2 else { return [] }
        var deltas: [Double] = []
        deltas.reserveCapacity(sortedTransactions.count - 1)
        for i in 1..<sortedTransactions.count {
            let seconds = sortedTransactions[i].date
                .timeIntervalSince(sortedTransactions[i - 1].date)
            deltas.append(seconds / 86_400)
        }
        return deltas
    }

    /// Matches the *average* interval (not each individual interval)
    /// to the nearest named bucket. Averaging prevents a single late
    /// bill from disqualifying an otherwise clean monthly pattern,
    /// while the tolerance keeps disparate cadences separate.
    private static func matchFrequency(_ intervalDays: [Double]) -> BillingFrequency? {
        guard !intervalDays.isEmpty else { return nil }
        let average = intervalDays.reduce(0, +) / Double(intervalDays.count)

        for bucket in frequencyBuckets {
            if abs(average - bucket.expectedDays) <= bucket.toleranceDays {
                return bucket.frequency
            }
        }
        return nil
    }

    private static func confidence(
        matchedCount: Int,
        intervalDays: [Double]
    ) -> RecurringChargeConfidence {
        if matchedCount >= 3 {
            return .high
        }
        if matchedCount == 2 {
            let reasonable = intervalDays.allSatisfy { days in
                days >= 5 && days <= 400
            }
            return reasonable ? .medium : .low
        }
        return .low
    }

    private static func estimateNextDate(
        after lastDate: Date,
        frequency: BillingFrequency
    ) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let component: Calendar.Component
        let value: Int
        switch frequency {
        case .weekly:
            component = .weekOfYear
            value = 1
        case .monthly:
            component = .month
            value = 1
        case .quarterly:
            component = .month
            value = 3
        case .annual:
            component = .year
            value = 1
        }
        return calendar.date(byAdding: component, value: value, to: lastDate) ?? lastDate
    }

    // MARK: - Grouping helpers

    private struct GroupKey: Hashable {
        let merchantKey: String
        let currency: CurrencyCode
    }

    @MainActor
    private static func groupByAmount(_ transactions: [Transaction]) -> [[Transaction]] {
        var groups: [[Transaction]] = []
        for transaction in transactions {
            let magnitude = abs(transaction.originalAmount)
            if let index = groups.firstIndex(where: { group in
                guard let representative = group.first else { return false }
                let representativeMagnitude = abs(representative.originalAmount)
                guard representativeMagnitude > 0 else { return false }
                return abs(magnitude - representativeMagnitude)
                    <= representativeMagnitude * amountTolerancePercent
            }) {
                groups[index].append(transaction)
            } else {
                groups.append([transaction])
            }
        }
        return groups
    }

    /// Returns the canonical normalisation for a transaction: prefer
    /// the persisted `normalizedMerchantName` that CSV import writes,
    /// falling back to running `MerchantNormalizer` on the raw name
    /// so legacy / manual rows still cluster.
    private static func normalizedKey(for transaction: Transaction) -> String {
        if let stored = transaction.normalizedMerchantName,
           !stored.isEmpty {
            return stored
        }
        return MerchantNormalizer.normalize(transaction.merchantName)
    }

    private static func stableID(
        merchantKey: String,
        amount: Double,
        currency: CurrencyCode
    ) -> String {
        let rounded = (amount * 100).rounded() / 100
        return "\(merchantKey)|\(String(format: "%.2f", rounded))|\(currency.rawValue)"
    }
}
