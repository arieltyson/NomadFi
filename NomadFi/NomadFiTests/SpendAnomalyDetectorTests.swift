// SpendAnomalyDetectorTests.swift
// NomadFi
//
// Pure coverage for the Phase-4-stretch anomaly detector. The
// detector sits on top of `RecurringChargeDetector`, so every
// scenario here builds synthetic `Transaction` values and relies
// on the recurring detector to produce the baseline — no
// ModelContainer needed.
//
// Pins:
//   • Minimum history: `SpendAnomalyDetector.minimumHistoryCount`.
//   • Spike threshold: `amountSpikePercentThreshold` + absolute
//     delta floor `amountSpikeMinimumDelta`.
//   • Missing-charge grace + max-overdue windows per cadence.
//   • One-off merchants, transfers, income, and multi-currency
//     rows never merge into a single anomaly.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct SpendAnomalyDetectorTests {

    // MARK: - Helpers

    nonisolated private static func date(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private static func transaction(
        merchant: String = "Streaming Plus",
        amount: Double,
        currency: CurrencyCode = .usd,
        category: TransactionCategory = .subscription,
        date: Date
    ) -> Transaction {
        Transaction(
            merchantName: merchant,
            originalAmount: amount,
            originalCurrency: currency,
            date: date,
            category: category,
            normalizedMerchantName: MerchantNormalizer.normalize(merchant)
        )
    }

    // MARK: - Missing recurring charge

    @Test("A monthly charge inside the 7-day grace window is NOT flagged as missing")
    func missingNotFlaggedInsideGrace() {
        // Three prior monthly charges; expected next = May 15, 2026.
        // `now` is May 20 — 5 days after expected. Grace for monthly
        // is 7 days → no anomaly yet.
        let txs = [
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 20)

        let anomalies = SpendAnomalyDetector.detect(from: txs, now: now)
        #expect(anomalies.allSatisfy { $0.kind != .missingRecurringCharge })
    }

    @Test("A monthly charge past the grace window and inside max-overdue is flagged as missing")
    func missingFlaggedPastGrace() throws {
        let txs = [
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        // Expected next = May 15, 2026. Now = May 30 → 15 days over,
        // well past the 7-day grace and inside the 45-day max.
        let now = Self.date(year: 2026, month: 5, day: 30)

        let anomalies = SpendAnomalyDetector.detect(from: txs, now: now)
        let missing = anomalies.first(where: { $0.kind == .missingRecurringCharge })
        let anomaly = try #require(missing)

        #expect(anomaly.displayMerchantName == "Streaming Plus")
        #expect(anomaly.baselineAmount == 15.99)
        #expect(anomaly.observedAmount == nil)
        #expect(anomaly.historyCount == 3)
        #expect(anomaly.currencyCode == .usd)
        #expect(anomaly.frequency == .monthly)
        let expected = try #require(anomaly.expectedDate)
        #expect(expected == Self.date(year: 2026, month: 5, day: 15))
    }

    @Test("A missing recurring charge past the max-overdue window is silently dropped (not stale noise)")
    func missingBeyondMaxOverdueIsDropped() {
        let txs = [
            Self.transaction(amount: -15.99, date: Self.date(year: 2025, month: 1, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2025, month: 2, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2025, month: 3, day: 15)),
        ]
        // Expected next = Apr 15 2025. Now = Apr 2026 → ~365 days
        // overdue, way beyond the 45-day max for monthly.
        let now = Self.date(year: 2026, month: 4, day: 15)

        let anomalies = SpendAnomalyDetector.detect(from: txs, now: now)
        #expect(anomalies.allSatisfy { $0.kind != .missingRecurringCharge })
    }

    @Test("If a matching charge exists in the expected window, the missing-charge anomaly is suppressed")
    func missingSuppressedWhenMatchExistsInWindow() {
        // Four monthly charges, then a fifth on May 17 (2 days after
        // expected May 15 and still inside the 7-day grace).
        let txs = [
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 5, day: 17)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 30)
        let anomalies = SpendAnomalyDetector.detect(from: txs, now: now)
        #expect(anomalies.allSatisfy { $0.kind != .missingRecurringCharge })
    }

    // MARK: - Amount spike

    @Test("A latest charge well above the baseline is flagged as an amount spike")
    func spikeDetectedAboveThreshold() throws {
        let txs = [
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -21, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 4, day: 1)),
            // Latest — 120 % above the ~20.33 baseline.
            Self.transaction(amount: -45, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 2)

        let anomalies = SpendAnomalyDetector.detect(from: txs, now: now)
        let spike = anomalies.first(where: { $0.kind == .amountSpike })
        let anomaly = try #require(spike)

        #expect(anomaly.observedAmount == 45)
        let expectedBaseline = (20.0 + 21.0 + 20.0) / 3.0
        #expect(abs(anomaly.baselineAmount - expectedBaseline) < 0.0001)
        #expect(anomaly.historyCount == 3)
        #expect(anomaly.kind == .amountSpike)
    }

    @Test("Small variance under the percent threshold does NOT flag a spike")
    func smallVarianceDoesNotTriggerSpike() {
        // ±1 % swings — recurring detector's own tolerance is ±5 %,
        // so these stay inside the same amount bucket and well below
        // the 25 % spike threshold.
        let txs = [
            Self.transaction(amount: -100, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -101, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -99, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -102, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 2)
        let anomalies = SpendAnomalyDetector.detect(from: txs, now: now)
        #expect(anomalies.allSatisfy { $0.kind != .amountSpike })
    }

    @Test("A spike that clears the percent threshold but fails the absolute $5 delta floor is not flagged")
    func spikeBelowAbsoluteDeltaFloorIsNotFlagged() {
        // Baseline ≈ $3. Latest $4 → +33 % but only $1 delta, under
        // the $5 absolute floor.
        let txs = [
            Self.transaction(amount: -3, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -3, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -3, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -4, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        // These are outside the recurring detector's ±5 % bucket so
        // they won't pair at all — but even if they did, the
        // absolute-delta floor would keep them quiet.
        let now = Self.date(year: 2026, month: 5, day: 2)
        let anomalies = SpendAnomalyDetector.detect(from: txs, now: now)
        #expect(anomalies.isEmpty)
    }

    // MARK: - Guard rails

    @Test("A one-off merchant with a single charge never produces an anomaly")
    func oneOffMerchantProducesNoAnomaly() {
        let txs = [
            Self.transaction(merchant: "Random One-Off", amount: -200, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 30)
        #expect(SpendAnomalyDetector.detect(from: txs, now: now).isEmpty)
    }

    @Test("Merchants with only two charges never qualify — minimum history is three")
    func twoChargesDoNotMeetMinimumHistory() {
        let txs = [
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 4, day: 1)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 30)
        #expect(SpendAnomalyDetector.detect(from: txs, now: now).isEmpty)
    }

    @Test("Different currencies produce separate anomalies — never a merged one")
    func differentCurrenciesStaySeparate() throws {
        // Four USD monthly charges, with a spike on the fourth.
        let usd = [
            Self.transaction(amount: -10, currency: .usd, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -10, currency: .usd, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -10, currency: .usd, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -45, currency: .usd, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        // Four CAD monthly charges, steady — no spike.
        let cad = [
            Self.transaction(amount: -12, currency: .cad, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -12, currency: .cad, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -12, currency: .cad, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -12, currency: .cad, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 2)
        let anomalies = SpendAnomalyDetector.detect(from: usd + cad, now: now)
        let spikes = anomalies.filter { $0.kind == .amountSpike }

        // Exactly one spike — the USD one — and it never bleeds
        // into the CAD currency bucket.
        #expect(spikes.count == 1)
        let spike = try #require(spikes.first)
        #expect(spike.currencyCode == .usd)
    }

    @Test("Transfers never produce anomalies even when they repeat every month with a big jump")
    func transfersExcluded() {
        let txs = [
            Self.transaction(amount: -500, category: .transfer, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -500, category: .transfer, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -500, category: .transfer, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -1_200, category: .transfer, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 2)
        #expect(SpendAnomalyDetector.detect(from: txs, now: now).isEmpty)
    }

    @Test("Income rows never produce anomalies even with a spike or a missing payroll run")
    func incomeExcluded() {
        let txs = [
            Self.transaction(merchant: "Payroll", amount: 2_000, category: .income, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.transaction(merchant: "Payroll", amount: 2_000, category: .income, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.transaction(merchant: "Payroll", amount: 2_000, category: .income, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 30)
        #expect(SpendAnomalyDetector.detect(from: txs, now: now).isEmpty)
    }

    // MARK: - Copy guard

    @Test("Every anomaly explanation and kind caption avoids the banned Phase-4 vocabulary")
    func copyGuardOnAnomalyCopy() {
        let bannedPhrases: [String] = [
            "fraud",
            "guaranteed anomaly",
            "guaranteed",
            "will happen",
            "this charge is wrong",
            "you were overcharged",
        ]

        var inspected: [String] = []
        for kind in SpendAnomalyKind.allCases {
            inspected.append(kind.displayTitle)
            inspected.append(kind.accessibilityLabel)
        }

        // Build two anomalies (one missing + one spike) and sweep
        // their explanations.
        let missingTxs = [
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let missingNow = Self.date(year: 2026, month: 5, day: 30)
        let missingAnomalies = SpendAnomalyDetector.detect(from: missingTxs, now: missingNow)

        let spikeTxs = [
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -21, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -45, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        let spikeNow = Self.date(year: 2026, month: 5, day: 2)
        let spikeAnomalies = SpendAnomalyDetector.detect(from: spikeTxs, now: spikeNow)

        for anomaly in missingAnomalies + spikeAnomalies {
            inspected.append(anomaly.explanation)
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in anomaly copy: \(copy)"
                )
            }
        }
    }

    // MARK: - Usage-based merchants

    @Test("A merchant charged many times a month in varying amounts is not a recurring charge, so it never produces an anomaly")
    func usageBasedMerchantProducesNoAnomalies() {
        // A car share: several trips a month. Some fares repeat, which
        // forms an amount cluster that looks monthly on its own.
        var txs: [Transaction] = []
        for month in 1...10 {
            for (day, fare) in [(2, -8.10), (6, -13.00), (9, -22.40), (13, -8.05), (17, -31.75), (21, -12.90), (26, -17.20)] {
                txs.append(Self.transaction(merchant: "City Car Share", amount: fare, category: .transport,
                                            date: Self.date(year: 2026, month: month, day: day)))
            }
        }
        txs.append(Self.transaction(merchant: "City Car Share", amount: -20.73, category: .transport,
                                    date: Self.date(year: 2026, month: 11, day: 8)))

        let anomalies = SpendAnomalyDetector.detect(from: txs, now: Self.date(year: 2026, month: 11, day: 10))
        #expect(anomalies.isEmpty)
        #expect(RecurringChargeDetector.detect(from: txs, now: Self.date(year: 2026, month: 11, day: 10)).isEmpty)
    }

    @Test("A merchant is reported at most once")
    func oneAnomalyPerMerchant() {
        let txs = [
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -45, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        let anomalies = SpendAnomalyDetector.detect(from: txs, now: Self.date(year: 2026, month: 5, day: 2))
        #expect(Set(anomalies.map(\.normalizedMerchantKey)).count == anomalies.count)
    }
}
