// SpendingTrendSummary.swift
// NomadFi
//
// Value type surfaced on the Dashboard when the user has imported
// or entered enough transactions to see where money is going.
// Purely deterministic — binned by calendar month and category.
// The home-currency label is carried as-is; no FX inference runs
// at this layer so the trend card stays honest about what the
// transactions themselves reported.

import Foundation

/// A single (year, month) bucket. Stable, comparable, and
/// display-formatted in a locale-aware way so `MonthKey(2026, 4)`
/// reads as "April 2026" in US English.
struct SpendingTrendMonth: Sendable, Hashable, Comparable {
    let year: Int
    let month: Int

    /// ISO-style key for logs / diagnostics — never shown in the UI.
    var iso: String {
        String(format: "%04d-%02d", year, month)
    }

    /// Absolute month label for the UI. Locale-aware so users outside
    /// the US still see their language; never a relative ("last
    /// month") string because the trend card is about concrete
    /// months, not elapsed time.
    func displayLabel(locale: Locale = .current) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            return iso
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    static func < (lhs: SpendingTrendMonth, rhs: SpendingTrendMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }
}

/// One row of the trend card: a category and its per-month totals
/// across the configured window. Totals are absolute magnitudes,
/// never signed.
struct SpendingTrendCategoryRow: Sendable, Equatable, Identifiable {
    var id: String { category.rawValue }
    let category: TransactionCategory
    /// Ordered parallel to ``SpendingTrendSummary/months`` — missing
    /// months are reported as zero, so UI code doesn't need to
    /// null-check per cell.
    let totalsByMonth: [Double]
    /// Sum of ``totalsByMonth`` — pre-computed so the UI can sort
    /// rows without re-reducing.
    let totalForWindow: Double
}

/// Full trend summary, or `nil` if the dataset doesn't clear the
/// "meaningful" threshold — the Dashboard then hides the card
/// rather than showing a confusing flat row.
struct SpendingTrendSummary: Sendable, Equatable {
    /// Oldest-to-newest months covered by the summary.
    let months: [SpendingTrendMonth]
    /// Rows sorted by total spend desc so "where money actually
    /// goes" surfaces first.
    let categoryRows: [SpendingTrendCategoryRow]
    /// Per-month totals across every category. Parallel to
    /// ``months``.
    let totalsByMonth: [Double]
    /// The currency label the card renders. NomadFi does not convert
    /// between currencies at this layer — if transactions were
    /// recorded in mixed currencies the card shows the dominant
    /// currency and flags the count of rows that used another.
    let currencyCode: CurrencyCode
    /// Total transactions that contributed to the summary after the
    /// eligibility filter.
    let contributingTransactionCount: Int
    /// Transactions that were in the input window but recorded in a
    /// different currency than ``currencyCode``. Surfaced as a
    /// caveat on the card so users know the trend isn't the whole
    /// picture.
    let skippedOtherCurrencyCount: Int
}
