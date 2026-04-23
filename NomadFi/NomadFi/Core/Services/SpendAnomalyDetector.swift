// SpendAnomalyDetector.swift
// NomadFi
//
// Deterministic spend-anomaly detector. Runs on top of the
// existing `RecurringChargeDetector` so only rows that have
// already proven a cadence can ever produce an anomaly. Two
// narrow, explainable signals:
//
//   • `.missingRecurringCharge` — the expected next charge has
//     passed a conservative grace window and the detector can't
//     see a matching charge in the user's history.
//   • `.amountSpike` — the latest matching charge is materially
//     higher than the mean of prior matching charges for the
//     same merchant + currency bucket.
//
// Everything here is pure. No SwiftData writes, no network, no
// ML. Every threshold is a single-file constant pinned by the
// focused test suite.

import Foundation
import OSLog

/// Pure detector. Call `detect(from:now:)` with any transaction
/// list; the detector runs `RecurringChargeDetector` internally.
enum SpendAnomalyDetector {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "SpendAnomalyDetector"
    )

    // MARK: - Rule constants (pinned in tests)

    /// Minimum number of matching charges before a candidate is
    /// allowed to spawn an anomaly. Two is enough for
    /// `RecurringChargeDetector` to see a cadence, but we require
    /// three so the baseline we compare against has at least two
    /// prior points.
    static let minimumHistoryCount: Int = 3

    /// Fractional threshold over the baseline that triggers an
    /// `.amountSpike`. A latest charge ≥ 25 % above the mean of
    /// prior matching charges counts as a spike. The recurring
    /// detector itself tolerates ±5 % jitter, so 25 % is well
    /// beyond normal drift.
    static let amountSpikePercentThreshold: Double = 0.25

    /// Absolute floor that must be cleared in addition to the
    /// percent threshold. Avoids flagging a $4.10 charge on a
    /// $3.00 baseline as a spike just because the math says 36 %.
    static let amountSpikeMinimumDelta: Double = 5.0

    // MARK: - Public API

    /// Detects anomalies in a set of transactions. Runs
    /// `RecurringChargeDetector` internally so callers never have
    /// to maintain two normalised transaction lists.
    ///
    /// - Parameters:
    ///   - transactions: Any slice of the user's transactions.
    ///   - now: Reference "now" for overdue comparisons. Tests
    ///     inject a deterministic value.
    /// - Returns: Anomalies sorted by recency so the UI renders
    ///   the freshest, most actionable signal first.
    @MainActor
    static func detect(
        from transactions: [Transaction],
        now: Date = .now
    ) -> [SpendAnomaly] {
        let candidates = RecurringChargeDetector.detect(
            from: transactions,
            now: now
        )

        var anomalies: [SpendAnomaly] = []
        for candidate in candidates {
            guard candidate.matchedTransactionCount >= minimumHistoryCount,
                  candidate.confidence != .low else {
                continue
            }

            let bucketMatches = bucketMatchingTransactions(
                for: candidate,
                in: transactions
            )
            guard bucketMatches.count >= minimumHistoryCount else {
                continue
            }

            // Spike detection has to look beyond the candidate's
            // own amount bucket — a spike by definition sits
            // *outside* the ±5 % bucket that produced the baseline.
            let broadMatches = broadMatchingTransactions(
                for: candidate,
                in: transactions
            )

            if let anomaly = amountSpike(
                for: candidate,
                bucketMatches: bucketMatches,
                broadMatches: broadMatches
            ) {
                anomalies.append(anomaly)
                continue
            }

            if let anomaly = missingCharge(
                for: candidate,
                matches: bucketMatches,
                now: now
            ) {
                anomalies.append(anomaly)
            }
        }

        let sorted = anomalies.sorted { $0.lastChargeDate > $1.lastChargeDate }
        logger.info("Detected \(sorted.count) spend anomalies from \(transactions.count) transactions")
        return sorted
    }

    // MARK: - Missing recurring charge

    /// Grace window and upper-bound actionable window for each
    /// cadence bucket. Anything beyond `maxOverdueDays` is
    /// considered ancient and silently dropped — the surface is
    /// about recent actionable review, not archaeology.
    private static let missingChargeWindows:
        [BillingFrequency: (graceDays: Double, maxOverdueDays: Double)] = [
        .weekly: (graceDays: 3, maxOverdueDays: 14),
        .monthly: (graceDays: 7, maxOverdueDays: 45),
        .quarterly: (graceDays: 14, maxOverdueDays: 120),
        .annual: (graceDays: 30, maxOverdueDays: 400),
    ]

    @MainActor
    private static func missingCharge(
        for candidate: RecurringChargeCandidate,
        matches: [Transaction],
        now: Date
    ) -> SpendAnomaly? {
        guard let window = missingChargeWindows[candidate.frequency] else {
            return nil
        }

        // We anchor the expected date to the last matching charge +
        // the cadence — this mirrors what the recurring detector
        // computed in `nextEstimatedDate`.
        let expected = candidate.nextEstimatedDate
        let daysOverdue = now.timeIntervalSince(expected) / 86_400
        guard daysOverdue > window.graceDays,
              daysOverdue <= window.maxOverdueDays else {
            return nil
        }

        // Guard against false positives: if the user has logged a
        // matching charge somewhere between `[expected - grace,
        // now]`, the charge is NOT missing. `matches` is already
        // scoped to this candidate's merchant + currency + amount
        // bucket.
        let observationWindowStart = expected.addingTimeInterval(-window.graceDays * 86_400)
        let recentMatch = matches.contains { transaction in
            transaction.date >= observationWindowStart && transaction.date <= now
        }
        if recentMatch { return nil }

        let expectedDateString = isoDateString(for: expected)
        let displayDate = expected.formatted(
            .dateTime.year().month(.wide).day()
        )
        let baselineString = candidate.representativeAmount.formatted(
            .currency(code: candidate.currencyCode.rawValue)
        )
        let daysLabel = "\(Int(daysOverdue.rounded(.down))) day\(Int(daysOverdue.rounded(.down)) == 1 ? "" : "s")"
        let explanation = "Based on \(matches.count) prior \(candidate.frequency.displayName.lowercased()) \(matches.count == 1 ? "charge" : "charges"), your \(candidate.displayMerchantName) charge near \(displayDate) (\(baselineString)) has not appeared in the last \(daysLabel). Worth reviewing."

        return SpendAnomaly(
            id: "spend-anomaly-\(candidate.id)-\(SpendAnomalyKind.missingRecurringCharge.rawValue)-\(expectedDateString)",
            kind: .missingRecurringCharge,
            displayMerchantName: candidate.displayMerchantName,
            normalizedMerchantKey: candidate.normalizedMerchantKey,
            currencyCode: candidate.currencyCode,
            frequency: candidate.frequency,
            baselineAmount: candidate.representativeAmount,
            observedAmount: nil,
            lastChargeDate: candidate.lastChargeDate,
            expectedDate: expected,
            historyCount: matches.count,
            explanation: explanation
        )
    }

    // MARK: - Amount spike

    /// The spike candidate is always the most recent merchant +
    /// currency match, regardless of whether it sits inside the
    /// recurring detector's amount bucket — a spike by definition
    /// sits *outside* that bucket. The baseline is the mean of the
    /// bucket matches (the cadence the detector already validated).
    @MainActor
    private static func amountSpike(
        for candidate: RecurringChargeCandidate,
        bucketMatches: [Transaction],
        broadMatches: [Transaction]
    ) -> SpendAnomaly? {
        guard bucketMatches.count >= minimumHistoryCount else { return nil }

        let sortedBroad = broadMatches.sorted { $0.date < $1.date }
        guard let latest = sortedBroad.last else { return nil }

        // Ignore txs that slot cleanly into the cadence bucket —
        // those are just another normal recurring charge.
        let latestMagnitude = abs(latest.originalAmount)
        let tolerance = max(candidate.representativeAmount, 0.01)
            * RecurringChargeDetector.amountTolerancePercent
        if abs(latestMagnitude - candidate.representativeAmount) <= tolerance {
            return nil
        }

        let priors = bucketMatches.sorted { $0.date < $1.date }
        let baseline = priors.reduce(0.0) { $0 + abs($1.originalAmount) }
            / Double(priors.count)
        guard baseline > 0 else { return nil }

        let delta = latestMagnitude - baseline
        guard delta >= amountSpikeMinimumDelta else { return nil }

        let percentOver = delta / baseline
        guard percentOver >= amountSpikePercentThreshold else { return nil }

        let observedString = latestMagnitude.formatted(
            .currency(code: candidate.currencyCode.rawValue)
        )
        let baselineString = baseline.formatted(
            .currency(code: candidate.currencyCode.rawValue)
        )
        let displayDate = latest.date.formatted(
            .dateTime.year().month(.wide).day()
        )
        let explanation = "Based on \(priors.count) prior \(candidate.frequency.displayName.lowercased()) \(priors.count == 1 ? "charge" : "charges") (baseline \(baselineString)), the \(displayDate) \(candidate.displayMerchantName) charge was \(observedString). Worth reviewing."

        let isoDate = isoDateString(for: latest.date)
        return SpendAnomaly(
            id: "spend-anomaly-\(candidate.id)-\(SpendAnomalyKind.amountSpike.rawValue)-\(isoDate)",
            kind: .amountSpike,
            displayMerchantName: candidate.displayMerchantName,
            normalizedMerchantKey: candidate.normalizedMerchantKey,
            currencyCode: candidate.currencyCode,
            frequency: candidate.frequency,
            baselineAmount: baseline,
            observedAmount: latestMagnitude,
            lastChargeDate: latest.date,
            expectedDate: latest.date,
            historyCount: priors.count,
            explanation: explanation
        )
    }

    // MARK: - Matching

    /// Finds the transactions that fed `candidate` — same merchant
    /// normalisation + currency + amount bucket (±5 %) as the
    /// recurring detector used. Safe baseline for missing-charge
    /// detection.
    @MainActor
    private static func bucketMatchingTransactions(
        for candidate: RecurringChargeCandidate,
        in transactions: [Transaction]
    ) -> [Transaction] {
        let tolerance = max(candidate.representativeAmount, 0.01)
            * RecurringChargeDetector.amountTolerancePercent
        return broadMatchingTransactions(
            for: candidate,
            in: transactions
        )
        .filter { transaction in
            let magnitude = abs(transaction.originalAmount)
            return abs(magnitude - candidate.representativeAmount) <= tolerance
        }
    }

    /// Finds every eligible transaction that shares the candidate's
    /// merchant-key + currency, regardless of amount. Used to find
    /// spikes that don't fit the cadence bucket.
    @MainActor
    private static func broadMatchingTransactions(
        for candidate: RecurringChargeCandidate,
        in transactions: [Transaction]
    ) -> [Transaction] {
        transactions.filter { transaction in
            guard isEligible(transaction) else { return false }
            guard (transaction.originalCurrency ?? .usd) == candidate.currencyCode else { return false }
            let key = normalizedKey(for: transaction)
            return key == candidate.normalizedMerchantKey
        }
    }

    /// Same eligibility check `RecurringChargeDetector` applies.
    /// Reimplementing here instead of exposing the detector's
    /// private helper keeps the dependency surface small.
    @MainActor
    private static func isEligible(_ transaction: Transaction) -> Bool {
        let category = transaction.category ?? .other
        if category == .income || category == .transfer { return false }
        return transaction.originalAmount != 0
    }

    /// Normalization aligned with `RecurringChargeDetector`: prefer
    /// the persisted normalized merchant name, fall back to
    /// `MerchantNormalizer` on the raw name.
    @MainActor
    private static func normalizedKey(for transaction: Transaction) -> String {
        if let stored = transaction.normalizedMerchantName,
           !stored.isEmpty {
            return stored
        }
        return MerchantNormalizer.normalize(transaction.merchantName)
    }

    // MARK: - Formatting

    private static func isoDateString(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
