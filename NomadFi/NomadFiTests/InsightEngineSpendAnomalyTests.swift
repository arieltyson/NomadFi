// InsightEngineSpendAnomalyTests.swift
// NomadFi
//
// Pins the contract between `SpendAnomalyDetector` and
// `InsightEngine`:
//
//   • Each anomaly becomes a `FinancialInsight` with `.anomaly`
//     category and `.userProvided` confidence (the data came from
//     the user's own transactions, not a verified external source).
//   • The card's title matches the kind's `displayTitle` and the
//     message echoes the detector's explanation verbatim so the
//     copy-guard coverage in `SpendAnomalyDetectorTests` also
//     covers everything the UI shows.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct InsightEngineSpendAnomalyTests {

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
        amount: Double,
        date: Date
    ) -> Transaction {
        Transaction(
            merchantName: "Streaming Plus",
            originalAmount: amount,
            originalCurrency: .usd,
            date: date,
            category: .subscription,
            normalizedMerchantName: MerchantNormalizer.normalize("Streaming Plus")
        )
    }

    // MARK: - Spike → insight

    @Test("An amount-spike anomaly surfaces as a .anomaly FinancialInsight with .userProvided confidence")
    func spikeBecomesAnomalyInsight() throws {
        let txs = [
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -21, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -45, date: Self.date(year: 2026, month: 5, day: 1)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 2)

        let insights = InsightEngine.spendAnomalyInsights(
            transactions: txs,
            now: now
        )
        let insight = try #require(insights.first)
        #expect(insight.category == .anomaly)
        #expect(insight.confidence == .userProvided)
        #expect(insight.title == "Streaming Plus cost more than usual")
        #expect(insight.message.localizedStandardContains("Usually about"))
        #expect(!insight.message.localizedStandardContains("Based on"), "The card states the fact, not the method")
    }

    // MARK: - Missing → insight

    @Test("A missing recurring-charge anomaly surfaces as a .anomaly FinancialInsight")
    func missingBecomesAnomalyInsight() throws {
        let txs = [
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let now = Self.date(year: 2026, month: 5, day: 30)

        let insights = InsightEngine.spendAnomalyInsights(
            transactions: txs,
            now: now
        )
        let insight = try #require(insights.first)
        #expect(insight.category == .anomaly)
        #expect(insight.title == "Streaming Plus hasn't charged")
        #expect(insight.message.localizedStandardContains("Nothing has appeared"))
    }

    // MARK: - Empty input

    @Test("When no anomaly fires, the anomaly generator returns no insights")
    func noAnomaliesProducesNoInsights() {
        let insights = InsightEngine.spendAnomalyInsights(
            transactions: [],
            now: Self.date(year: 2026, month: 5, day: 2)
        )
        #expect(insights.isEmpty)
    }

    // MARK: - Copy guard on the insight surface

    @Test("Anomaly insights never leak banned vocabulary into titles or messages")
    func copyGuardOnInsightSurface() {
        let bannedPhrases: [String] = [
            "fraud",
            "guaranteed anomaly",
            "guaranteed",
            "will happen",
            "this charge is wrong",
            "you were overcharged",
        ]

        let missingTxs = [
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.transaction(amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let spikeTxs = [
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 2, day: 1)),
            Self.transaction(amount: -21, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.transaction(amount: -20, date: Self.date(year: 2026, month: 4, day: 1)),
            Self.transaction(amount: -45, date: Self.date(year: 2026, month: 5, day: 1)),
        ]

        let insights = InsightEngine.spendAnomalyInsights(
            transactions: missingTxs,
            now: Self.date(year: 2026, month: 5, day: 30)
        ) + InsightEngine.spendAnomalyInsights(
            transactions: spikeTxs,
            now: Self.date(year: 2026, month: 5, day: 2)
        )

        for insight in insights {
            for phrase in bannedPhrases {
                #expect(
                    !insight.title.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in insight title: \(insight.title)"
                )
                #expect(
                    !insight.message.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in insight message: \(insight.message)"
                )
            }
        }
    }
}
