import Foundation

/// Everything the Dashboard derives from the full transaction history,
/// as plain values that can cross from the background worker to the UI.
struct DashboardDigest: Equatable, Sendable {

    /// Insights worth a look, most urgent first.
    let insights: [FinancialInsight]

    /// Where recent spending went, or `nil` when there is too little
    /// activity for a trend to mean anything.
    let spendingTrend: SpendingTrendSummary?
}
