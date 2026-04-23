// CreditTimingSpendingContextBuilder.swift
// NomadFi
//
// Pure builder that projects a `SpendingTrendSummary` into a
// `CreditTimingSpendingContext`. Takes no side effects, no
// SwiftData, no networking. Deterministic — same input, same
// output.
//
// Rules pinned in `CreditTimingSpendingContextBuilderTests`:
//   • Nil summary → nil context.
//   • Empty totalsByMonth → nil (there's nothing to describe).
//   • One month only → context with direction `.insufficient` and
//     `percentChange == nil`.
//   • Two months → prior month = baseline.
//   • Three or more months → trailing average of every month
//     except the latest is the baseline.
//   • Direction thresholds: ±5 % — `.rising` when change ≥ +0.05,
//     `.falling` when change ≤ -0.05, otherwise `.steady`.
//   • Zero baseline with positive latest → `.rising` with
//     `percentChange == nil` (avoid a divide-by-zero claim).
//   • Top categories: up to three, copied in order, zeros filtered
//     out so the UI doesn't render empty rows.

import Foundation

/// Projects a `SpendingTrendSummary` onto the shape the Credit
/// Timing brief consumes.
enum CreditTimingSpendingContextBuilder {

    /// Threshold for "rising" / "falling" versus "steady". Kept in
    /// one place so the tests pin the same number the UI renders.
    static let directionChangeThreshold: Double = 0.05

    /// Maximum categories carried into the context. The brief
    /// already stays calm by only listing a few.
    static let maxTopCategories: Int = 3

    // MARK: - Public API

    /// Builds a context or returns `nil` when the summary is too
    /// thin to describe.
    static func build(from summary: SpendingTrendSummary?) -> CreditTimingSpendingContext? {
        guard let summary,
              let latestMonth = summary.months.last,
              !summary.totalsByMonth.isEmpty
        else {
            return nil
        }

        let latestTotal = summary.totalsByMonth.last ?? 0
        let priorMonths = summary.months.dropLast()
        let priorTotals = summary.totalsByMonth.dropLast()

        let priorLabel: String
        let priorTotal: Double
        if priorTotals.isEmpty {
            priorLabel = "prior month"
            priorTotal = 0
        } else if priorTotals.count == 1 {
            priorLabel = "prior month"
            priorTotal = priorTotals.first ?? 0
        } else {
            priorLabel = "trailing \(priorTotals.count)-month average"
            priorTotal = priorTotals.reduce(0, +) / Double(priorTotals.count)
        }

        let (direction, percentChange) = classify(
            latest: latestTotal,
            prior: priorTotal,
            priorHasData: !priorMonths.isEmpty
        )

        let topCategories = summary.categoryRows
            .prefix(maxTopCategories)
            .filter { $0.totalForWindow > 0 }
            .map { row in
                CreditTimingSpendingContextCategory(
                    category: row.category,
                    totalForWindow: row.totalForWindow
                )
            }

        return CreditTimingSpendingContext(
            currencyCode: summary.currencyCode,
            latestMonth: latestMonth,
            latestMonthTotal: latestTotal,
            priorComparisonLabel: priorLabel,
            priorComparisonTotal: priorTotal,
            direction: direction,
            percentChange: percentChange,
            topCategories: topCategories,
            skippedOtherCurrencyCount: summary.skippedOtherCurrencyCount
        )
    }

    // MARK: - Direction classification

    private static func classify(
        latest: Double,
        prior: Double,
        priorHasData: Bool
    ) -> (CreditTimingSpendingDirection, Double?) {
        guard priorHasData else {
            return (.insufficient, nil)
        }

        if prior == 0 {
            if latest > 0 {
                // Can't honestly compute a percent change against a
                // zero baseline, but the direction itself is real.
                return (.rising, nil)
            }
            return (.steady, 0)
        }

        let change = (latest - prior) / prior
        if change >= directionChangeThreshold {
            return (.rising, change)
        }
        if change <= -directionChangeThreshold {
            return (.falling, change)
        }
        return (.steady, change)
    }
}
