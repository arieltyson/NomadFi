import Foundation

/// What one category took in the period, split into subcategories.
struct SpendingCategorySlice: Identifiable, Equatable, Sendable {
    let category: TransactionCategory
    let total: Double
    /// Largest first, with "Other" always last.
    let subcategories: [SpendingSubcategorySlice]

    var id: TransactionCategory { category }
}
