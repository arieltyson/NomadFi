// CreditTimingSpendingContext.swift
// NomadFi
//
// Pure value type the Credit Timing engine carries so the brief
// view can render a calm "Recent spending context" section.
// Derived entirely from the existing `SpendingTrendSummary`. No
// SwiftData, no SwiftUI, no FX inference — every number surfaces in
// the summary's own currency, and any cross-currency rows are
// counted as a caveat, never merged.

import Foundation

/// One category row inside the Credit Timing spending context.
/// Carried forward from the top rows of ``SpendingTrendSummary`` so
/// the brief can surface "where money actually went" without
/// re-running the trend computer.
struct CreditTimingSpendingContextCategory: Sendable, Equatable, Identifiable {
    var id: String { category.rawValue }
    let category: TransactionCategory
    /// Sum across the configured trend window, magnitude only.
    let totalForWindow: Double
}

/// Calm, non-promissory spending context for the Credit Timing
/// brief. Never used to change paydown targets — the Phase 6A
/// planner and readiness evaluator both ignore this type.
struct CreditTimingSpendingContext: Sendable, Equatable {

    /// Currency the numbers below are reported in. Inherits from
    /// ``SpendingTrendSummary/currencyCode`` — never converted.
    let currencyCode: CurrencyCode

    /// Most recent month the trend covered.
    let latestMonth: SpendingTrendMonth

    /// Magnitude total for ``latestMonth``. Always non-negative.
    let latestMonthTotal: Double

    /// Human-readable label for the baseline we're comparing
    /// against. Two flavours today — "prior month" when the trend
    /// had two months on file, or "trailing N-month average" when
    /// it had three or more.
    let priorComparisonLabel: String

    /// Magnitude total of the prior baseline. Zero when the trend
    /// didn't cover a prior month.
    let priorComparisonTotal: Double

    /// Bucketed direction of change. See
    /// ``CreditTimingSpendingDirection`` for the thresholds.
    let direction: CreditTimingSpendingDirection

    /// Signed fractional change from prior baseline to latest.
    /// `0.12` means latest is 12 % higher than the baseline;
    /// `-0.08` means 8 % lower. `nil` when the baseline is zero or
    /// when direction is ``CreditTimingSpendingDirection/insufficient``.
    let percentChange: Double?

    /// Top categories copied from ``SpendingTrendSummary/categoryRows``.
    /// Already sorted desc by `totalForWindow`. At most three entries.
    let topCategories: [CreditTimingSpendingContextCategory]

    /// Transactions that were in the window but in a different
    /// currency than ``currencyCode``. Surfaced so the brief can
    /// say "N other-currency rows are not shown" rather than
    /// silently drop them.
    let skippedOtherCurrencyCount: Int

    // MARK: - Derived

    /// Whether the direction carries real signal. UI uses this to
    /// decide if it should render the comparison sentence or fall
    /// back to a plain "latest month" caption.
    var hasComparison: Bool {
        direction != .insufficient
    }
}
