// SpendingTrendComputer.swift
// NomadFi
//
// Pure computer for `SpendingTrendSummary`. Called from the
// Dashboard VM whenever the underlying `Transaction` query changes.
//
// Rules (pinned in tests):
//   • Income and transfer categories are *never* counted as
//     spending — they are inflows or internal moves.
//   • Sign conventions vary by import profile, so the computer
//     always uses `abs(originalAmount)`. A user-typed `+50` food
//     expense and a CSV-imported `-50` food expense produce the
//     same bin.
//   • Only the dominant-currency rows feed the totals. Rows in a
//     different currency are counted separately so the Dashboard
//     can caveat the card.
//   • The summary requires a floor of activity; below that the
//     computer returns `nil` so the Dashboard hides the card.

import Foundation

/// Pure trend computer. No SwiftData, no UI types — call from any
/// actor, but touching `Transaction` fields requires the caller be
/// on the main actor where those fields are isolated.
enum SpendingTrendComputer {

    /// Minimum number of qualifying transactions required for the
    /// card to appear at all. Tuned low enough to be useful for new
    /// users with one CSV import but high enough to not show a
    /// single-transaction "trend".
    static let minimumContributingTransactions: Int = 3

    /// Default number of months the card covers. Kept small so the
    /// grid fits on an iPhone in Dynamic Type without horizontal
    /// scrolling.
    static let defaultMonthsBack: Int = 3

    /// Produces a trend summary or `nil` if the input doesn't meet
    /// the display threshold.
    ///
    /// - Parameters:
    ///   - transactions: All in-scope transactions. Filtering for
    ///     the month window happens inside — callers can pass the
    ///     full `@Query` result.
    ///   - now: The anchor "today" date. Injected for tests.
    ///   - monthsBack: Number of trailing months to include (current
    ///     month + the prior `monthsBack - 1` months).
    ///   - homeCurrency: Currency the Dashboard is already showing
    ///     net worth in. We try to honour it; if no transaction is
    ///     denominated in that currency we fall back to the most
    ///     common currency in the data so the card still renders.
    ///   - calendar: Calendar for month binning. Defaults to
    ///     Gregorian so tests remain deterministic across locales.
    @MainActor
    static func summary(
        transactions: [Transaction],
        now: Date = .now,
        monthsBack: Int = defaultMonthsBack,
        homeCurrency: CurrencyCode,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> SpendingTrendSummary? {
        guard monthsBack >= 1 else { return nil }

        let months = windowMonths(endingAt: now, monthsBack: monthsBack, calendar: calendar)
        guard let earliest = months.first else { return nil }

        let eligible = transactions.filter { isSpending($0) }
        guard !eligible.isEmpty else { return nil }

        // Only transactions that fall inside the display window
        // contribute to the totals. Others might still matter for
        // dominant-currency selection, so we keep them separate.
        let withinWindow = eligible.filter { transaction in
            let key = monthKey(for: transaction.date, calendar: calendar)
            return key >= earliest
        }

        guard withinWindow.count >= minimumContributingTransactions else {
            return nil
        }

        // Pick the currency that dominates the window — prefer the
        // caller's home currency, fall back to whichever currency
        // has the most rows. This keeps the trend card useful even
        // for users whose jurisdictions haven't been updated.
        let dominantCurrency = dominantCurrency(
            inWindow: withinWindow,
            preferred: homeCurrency
        )

        let contributing = withinWindow.filter { transaction in
            (transaction.originalCurrency ?? .usd) == dominantCurrency
        }
        guard contributing.count >= minimumContributingTransactions else {
            return nil
        }

        let skipped = withinWindow.count - contributing.count
        let categoryRows = categoryRows(
            for: contributing,
            months: months,
            calendar: calendar
        )

        // If after filtering every category row is zero, the card
        // would be misleading noise. Hide it.
        guard categoryRows.contains(where: { $0.totalForWindow > 0 }) else {
            return nil
        }

        let totalsByMonth = months.map { month in
            categoryRows.reduce(0) { running, row in
                let idx = months.firstIndex(of: month) ?? 0
                return running + row.totalsByMonth[idx]
            }
        }

        return SpendingTrendSummary(
            months: months,
            categoryRows: categoryRows,
            totalsByMonth: totalsByMonth,
            currencyCode: dominantCurrency,
            contributingTransactionCount: contributing.count,
            skippedOtherCurrencyCount: skipped
        )
    }

    // MARK: - Eligibility

    /// A spending row is any non-zero transaction that is not
    /// explicitly income or transfer. Sign is ignored — see the
    /// file header for why.
    private static func isSpending(_ transaction: Transaction) -> Bool {
        let category = transaction.category ?? .other
        if category == .income || category == .transfer {
            return false
        }
        return transaction.originalAmount != 0
    }

    // MARK: - Currency picking

    @MainActor
    private static func dominantCurrency(
        inWindow transactions: [Transaction],
        preferred: CurrencyCode
    ) -> CurrencyCode {
        if transactions.contains(where: { ($0.originalCurrency ?? .usd) == preferred }) {
            return preferred
        }
        var counts: [CurrencyCode: Int] = [:]
        for transaction in transactions {
            let code = transaction.originalCurrency ?? .usd
            counts[code, default: 0] += 1
        }
        // Deterministic tie-break on rawValue so tests don't flake.
        return counts
            .max { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return lhs.key.rawValue > rhs.key.rawValue
            }?
            .key ?? preferred
    }

    // MARK: - Month windowing

    private static func windowMonths(
        endingAt now: Date,
        monthsBack: Int,
        calendar: Calendar
    ) -> [SpendingTrendMonth] {
        let anchor = monthKey(for: now, calendar: calendar)
        var months: [SpendingTrendMonth] = [anchor]
        for offset in 1..<monthsBack {
            guard let previousDate = calendar.date(
                byAdding: .month,
                value: -offset,
                to: now
            ) else {
                continue
            }
            months.append(monthKey(for: previousDate, calendar: calendar))
        }
        return months.sorted()
    }

    private static func monthKey(
        for date: Date,
        calendar: Calendar
    ) -> SpendingTrendMonth {
        let components = calendar.dateComponents([.year, .month], from: date)
        return SpendingTrendMonth(
            year: components.year ?? 1970,
            month: components.month ?? 1
        )
    }

    // MARK: - Category reduction

    @MainActor
    private static func categoryRows(
        for transactions: [Transaction],
        months: [SpendingTrendMonth],
        calendar: Calendar
    ) -> [SpendingTrendCategoryRow] {
        // Seed every (category, month) with zero so consumers don't
        // have to branch on missing keys.
        var totals: [TransactionCategory: [SpendingTrendMonth: Double]] = [:]
        for transaction in transactions {
            let category = transaction.category ?? .other
            let month = monthKey(for: transaction.date, calendar: calendar)
            guard months.contains(month) else { continue }
            let magnitude = abs(transaction.originalAmount)
            totals[category, default: [:]][month, default: 0] += magnitude
        }

        return totals.map { (category, monthMap) in
            let parallelTotals = months.map { monthMap[$0] ?? 0 }
            let sum = parallelTotals.reduce(0, +)
            return SpendingTrendCategoryRow(
                category: category,
                totalsByMonth: parallelTotals,
                totalForWindow: sum
            )
        }
        .sorted { $0.totalForWindow > $1.totalForWindow }
    }
}
