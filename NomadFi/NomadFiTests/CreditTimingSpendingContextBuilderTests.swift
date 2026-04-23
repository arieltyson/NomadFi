// CreditTimingSpendingContextBuilderTests.swift
// NomadFi
//
// Pure coverage for the spending-context builder that feeds the
// Credit Timing brief. The builder is a value-in / value-out
// function, so there's no SwiftData container — tests run in
// parallel.
//
// The product contract pinned here:
//   • Nil or empty summaries return nil.
//   • One month of data → direction `.insufficient` with
//     `percentChange == nil`.
//   • Two months → prior month is the baseline.
//   • Three+ months → baseline is the trailing N-month average.
//   • ±5 % threshold is deterministic: 0.049 is steady, 0.05 is
//     rising.
//   • Zero baseline + positive latest → `.rising`, percentChange nil.
//   • Top categories cap at three, zero-only rows dropped.
//   • The other-currency skipped count passes through unchanged.

import Foundation
import Testing

@testable import NomadFi

struct CreditTimingSpendingContextBuilderTests {

    // MARK: - Fixture helpers

    private static func summary(
        months: [(year: Int, month: Int, total: Double)],
        categoryRows: [(category: TransactionCategory, total: Double)] = [],
        currency: CurrencyCode = .usd,
        contributing: Int = 10,
        skippedOtherCurrency: Int = 0
    ) -> SpendingTrendSummary {
        let trendMonths = months.map { SpendingTrendMonth(year: $0.year, month: $0.month) }
        let totals = months.map(\.total)
        let rows = categoryRows.map { row in
            SpendingTrendCategoryRow(
                category: row.category,
                totalsByMonth: Array(repeating: 0.0, count: totals.count),
                totalForWindow: row.total
            )
        }
        return SpendingTrendSummary(
            months: trendMonths,
            categoryRows: rows,
            totalsByMonth: totals,
            currencyCode: currency,
            contributingTransactionCount: contributing,
            skippedOtherCurrencyCount: skippedOtherCurrency
        )
    }

    // MARK: - Nil / empty handling

    @Test("Builder returns nil when the summary itself is nil")
    func nilSummaryReturnsNil() {
        #expect(CreditTimingSpendingContextBuilder.build(from: nil) == nil)
    }

    @Test("Builder returns nil when totalsByMonth is empty")
    func emptySummaryReturnsNil() {
        let empty = SpendingTrendSummary(
            months: [],
            categoryRows: [],
            totalsByMonth: [],
            currencyCode: .usd,
            contributingTransactionCount: 0,
            skippedOtherCurrencyCount: 0
        )
        #expect(CreditTimingSpendingContextBuilder.build(from: empty) == nil)
    }

    // MARK: - Insufficient signal

    @Test("Single-month summary → context with direction .insufficient and no percent change")
    func singleMonthIsInsufficient() throws {
        let input = Self.summary(months: [(2026, 4, 500)])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.direction == .insufficient)
        #expect(context.percentChange == nil)
        #expect(context.hasComparison == false)
        #expect(context.latestMonth == SpendingTrendMonth(year: 2026, month: 4))
        #expect(context.latestMonthTotal == 500)
    }

    // MARK: - Baseline selection

    @Test("Two-month summary uses the prior month as the baseline")
    func twoMonthsUsesPriorMonthBaseline() throws {
        let input = Self.summary(months: [
            (2026, 3, 400),
            (2026, 4, 520),
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.priorComparisonLabel == "prior month")
        #expect(context.priorComparisonTotal == 400)
    }

    @Test("Three-month summary uses the trailing two-month average as the baseline")
    func threeMonthsUsesTrailingAverageBaseline() throws {
        let input = Self.summary(months: [
            (2026, 2, 300),
            (2026, 3, 500),
            (2026, 4, 500),
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.priorComparisonLabel == "trailing 2-month average")
        // (300 + 500) / 2 == 400.
        #expect(context.priorComparisonTotal == 400)
    }

    // MARK: - Direction thresholds

    @Test("Latest month more than 5% above baseline → .rising")
    func risingDirection() throws {
        let input = Self.summary(months: [
            (2026, 3, 400),
            (2026, 4, 450), // +12.5 %
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.direction == .rising)
        let change = try #require(context.percentChange)
        #expect((change - 0.125).magnitude < 1e-9)
    }

    @Test("Latest month more than 5% below baseline → .falling")
    func fallingDirection() throws {
        let input = Self.summary(months: [
            (2026, 3, 400),
            (2026, 4, 300), // -25 %
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.direction == .falling)
        let change = try #require(context.percentChange)
        #expect((change - (-0.25)).magnitude < 1e-9)
    }

    @Test("Latest month within ±5% of baseline → .steady")
    func steadyDirection() throws {
        let input = Self.summary(months: [
            (2026, 3, 400),
            (2026, 4, 410), // +2.5 %
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.direction == .steady)
    }

    @Test("Exactly +5% crosses into .rising — threshold is inclusive")
    func exactThresholdIsRising() throws {
        let input = Self.summary(months: [
            (2026, 3, 400),
            (2026, 4, 420), // +5 %
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.direction == .rising)
    }

    @Test("Zero baseline and positive latest → .rising with a nil percent change")
    func zeroBaselineWithSpend() throws {
        let input = Self.summary(months: [
            (2026, 3, 0),
            (2026, 4, 250),
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.direction == .rising)
        #expect(context.percentChange == nil)
    }

    @Test("Zero baseline and zero latest → .steady with percent change of zero")
    func zeroBaselineAndLatest() throws {
        let input = Self.summary(months: [
            (2026, 3, 0),
            (2026, 4, 0),
        ])
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.direction == .steady)
        #expect(context.percentChange == 0)
    }

    // MARK: - Category pass-through

    @Test("Top categories are capped at three and zero-only rows are dropped")
    func topCategoriesCappedAndFiltered() throws {
        let input = Self.summary(
            months: [
                (2026, 3, 600),
                (2026, 4, 650),
            ],
            categoryRows: [
                (.food, 300),
                (.transport, 150),
                (.subscription, 90),
                (.entertainment, 60),
                (.other, 0),
            ]
        )
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.topCategories.count == 3)
        let categories = context.topCategories.map(\.category)
        #expect(categories == [.food, .transport, .subscription])
    }

    // MARK: - Currency / caveat pass-through

    @Test("Other-currency skipped count passes through unchanged")
    func otherCurrencyCountPassesThrough() throws {
        let input = Self.summary(
            months: [(2026, 3, 500), (2026, 4, 600)],
            skippedOtherCurrency: 4
        )
        let context = try #require(CreditTimingSpendingContextBuilder.build(from: input))
        #expect(context.skippedOtherCurrencyCount == 4)
    }

    // MARK: - Copy guard

    @Test("Direction display + accessibility copy never use the banned Phase 6 vocabulary")
    func copyGuardOnSpendingDirectionVocab() {
        let bannedPhrases: [String] = [
            "guarantee",
            "score will increase",
            "approved",
            "will spend",
            "will get a limit increase",
            "carry a balance",
        ]

        var inspected: [String] = []
        for direction in CreditTimingSpendingDirection.allCases {
            inspected.append(direction.displaySummary)
            inspected.append(direction.accessibilityLabel)
        }
        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in direction copy: \(copy)"
                )
            }
        }
    }
}
