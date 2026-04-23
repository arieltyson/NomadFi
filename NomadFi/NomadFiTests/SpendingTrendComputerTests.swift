// SpendingTrendComputerTests.swift
// NomadFi
//
// Pure coverage for the Dashboard trend computer. No SwiftData
// container — the computer works on `[Transaction]` values and
// returns a pure `SpendingTrendSummary`. Pins the three product
// invariants the card depends on: income/transfers never count,
// both sign conventions produce the same bin, and the computer
// returns `nil` when there's not enough activity.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct SpendingTrendComputerTests {

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
        components.hour = 12
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    nonisolated private static let now = date(year: 2026, month: 4, day: 30)

    private static func transaction(
        amount: Double,
        currency: CurrencyCode = .usd,
        category: TransactionCategory,
        day: Int,
        month: Int,
        year: Int = 2026
    ) -> Transaction {
        Transaction(
            merchantName: "Merchant",
            originalAmount: amount,
            originalCurrency: currency,
            date: date(year: year, month: month, day: day),
            category: category
        )
    }

    // MARK: - Binning

    @Test("Transactions bin by calendar month and category into the trend summary")
    func binsByMonthAndCategory() throws {
        let transactions: [Transaction] = [
            Self.transaction(amount: -50, category: .food, day: 5, month: 3),
            Self.transaction(amount: -25, category: .food, day: 20, month: 3),
            Self.transaction(amount: -80, category: .food, day: 2, month: 4),
            Self.transaction(amount: -15, category: .transport, day: 10, month: 4),
            Self.transaction(amount: -15, category: .transport, day: 11, month: 4),
        ]

        let summary = try #require(
            SpendingTrendComputer.summary(
                transactions: transactions,
                now: Self.now,
                monthsBack: 3,
                homeCurrency: .usd
            )
        )

        #expect(summary.months.count == 3)
        let expectedMonths: [SpendingTrendMonth] = [
            SpendingTrendMonth(year: 2026, month: 2),
            SpendingTrendMonth(year: 2026, month: 3),
            SpendingTrendMonth(year: 2026, month: 4),
        ]
        #expect(summary.months == expectedMonths)

        let foodRow = summary.categoryRows.first(where: { (row: SpendingTrendCategoryRow) in
            row.category == TransactionCategory.food
        })
        #expect(foodRow?.totalsByMonth == [0, 75, 80])
        #expect(foodRow?.totalForWindow == 155)

        let transportRow = summary.categoryRows.first(where: { (row: SpendingTrendCategoryRow) in
            row.category == TransactionCategory.transport
        })
        #expect(transportRow?.totalsByMonth == [0, 0, 30])

        // Rows sorted desc by total — food (155) before transport (30).
        #expect(summary.categoryRows.first?.category == TransactionCategory.food)
        #expect(summary.totalsByMonth == [0, 75, 110])
        #expect(summary.contributingTransactionCount == 5)
    }

    // MARK: - Eligibility

    @Test("Income and transfer categories never contribute to spending totals")
    func incomeAndTransfersExcluded() throws {
        let transactions: [Transaction] = [
            Self.transaction(amount: 2_000, category: .income, day: 1, month: 4),
            Self.transaction(amount: -500, category: .transfer, day: 2, month: 4),
            Self.transaction(amount: -20, category: .food, day: 3, month: 4),
            Self.transaction(amount: -30, category: .food, day: 5, month: 4),
            Self.transaction(amount: -10, category: .food, day: 8, month: 4),
        ]

        let summary = try #require(
            SpendingTrendComputer.summary(
                transactions: transactions,
                now: Self.now,
                homeCurrency: .usd
            )
        )

        // The $2 000 income and $500 transfer must never appear in
        // the spending totals — even though transfer is a negative
        // outflow.
        let categories: [TransactionCategory] = summary.categoryRows.map { $0.category }
        #expect(categories == [TransactionCategory.food])
        #expect(summary.categoryRows.first?.totalForWindow == 60)
        #expect(summary.contributingTransactionCount == 3)
    }

    // MARK: - Sign convention

    @Test("Spending normalizes to magnitude — positive and negative sign conventions produce the same totals")
    func signConventionNormalisation() throws {
        let negativeConvention: [Transaction] = [
            Self.transaction(amount: -50, category: .food, day: 5, month: 4),
            Self.transaction(amount: -25, category: .food, day: 10, month: 4),
            Self.transaction(amount: -15, category: .transport, day: 12, month: 4),
        ]
        let positiveConvention: [Transaction] = [
            Self.transaction(amount: 50, category: .food, day: 5, month: 4),
            Self.transaction(amount: 25, category: .food, day: 10, month: 4),
            Self.transaction(amount: 15, category: .transport, day: 12, month: 4),
        ]

        let negativeSummary = try #require(
            SpendingTrendComputer.summary(
                transactions: negativeConvention,
                now: Self.now,
                homeCurrency: .usd
            )
        )
        let positiveSummary = try #require(
            SpendingTrendComputer.summary(
                transactions: positiveConvention,
                now: Self.now,
                homeCurrency: .usd
            )
        )

        #expect(negativeSummary.categoryRows == positiveSummary.categoryRows)
        #expect(negativeSummary.totalsByMonth == positiveSummary.totalsByMonth)
    }

    // MARK: - Threshold

    @Test("Below the minimum-contributing floor the computer returns nil so the card hides")
    func insufficientDataReturnsNil() {
        let transactions: [Transaction] = [
            Self.transaction(amount: -20, category: .food, day: 5, month: 4),
            Self.transaction(amount: -25, category: .food, day: 10, month: 4),
        ]

        let summary = SpendingTrendComputer.summary(
            transactions: transactions,
            now: Self.now,
            homeCurrency: .usd
        )

        #expect(summary == nil)
    }

    @Test("Empty input returns nil")
    func emptyInputReturnsNil() {
        let summary = SpendingTrendComputer.summary(
            transactions: [],
            now: Self.now,
            homeCurrency: .usd
        )
        #expect(summary == nil)
    }

    @Test("Transactions outside the month window don't contribute, and if that leaves too few, the summary is nil")
    func outOfWindowTransactionsExcluded() {
        // With a 3-month window ending 2026-04, only Feb–Apr should
        // count. Transactions from 2025 fall out.
        let transactions: [Transaction] = [
            Self.transaction(amount: -50, category: .food, day: 5, month: 4, year: 2025),
            Self.transaction(amount: -25, category: .food, day: 20, month: 4, year: 2025),
            Self.transaction(amount: -30, category: .food, day: 2, month: 4, year: 2025),
        ]

        let summary = SpendingTrendComputer.summary(
            transactions: transactions,
            now: Self.now,
            monthsBack: 3,
            homeCurrency: .usd
        )
        #expect(summary == nil)
    }

    // MARK: - Currency handling

    @Test("Rows in a different currency are counted separately and surfaced as a caveat")
    func otherCurrencyRowsAreCaveated() throws {
        let transactions: [Transaction] = [
            Self.transaction(amount: -50, category: .food, day: 5, month: 4),
            Self.transaction(amount: -25, category: .food, day: 10, month: 4),
            Self.transaction(amount: -30, category: .food, day: 15, month: 4),
            Self.transaction(amount: -40, currency: .cad, category: .food, day: 20, month: 4),
        ]

        let summary = try #require(
            SpendingTrendComputer.summary(
                transactions: transactions,
                now: Self.now,
                homeCurrency: .usd
            )
        )

        #expect(summary.currencyCode == CurrencyCode.usd)
        #expect(summary.contributingTransactionCount == 3)
        #expect(summary.skippedOtherCurrencyCount == 1)
    }

    // MARK: - Month labels

    @Test("SpendingTrendMonth.displayLabel renders an absolute 'Month Year' string, never a relative date")
    func monthLabelIsAbsolute() {
        let month = SpendingTrendMonth(year: 2026, month: 4)
        let label = month.displayLabel(locale: Locale(identifier: "en_US"))

        #expect(label.contains("April"))
        #expect(label.contains("2026"))
        // Guard against accidental relative formatting in the future.
        let lowered = label.lowercased()
        #expect(!lowered.contains("last"))
        #expect(!lowered.contains("ago"))
    }
}
