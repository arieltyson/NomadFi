import Foundation

/// Where the money went in a period: categories, their subcategories and
/// the merchants within them, all in one currency.
struct SpendingBreakdown: Equatable, Sendable {
    let period: SpendingPeriod
    let currency: CurrencyCode
    let total: Double
    /// Largest first.
    let categories: [SpendingCategorySlice]
    /// Purchases left out because they were in another currency, so the
    /// totals never mix currencies.
    let otherCurrencyCount: Int

    func slice(for category: TransactionCategory) -> SpendingCategorySlice? {
        categories.first { $0.category == category }
    }
}
