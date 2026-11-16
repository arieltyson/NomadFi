import Foundation

/// What one subcategory, or a category's "Other", took in the period.
struct SpendingSubcategorySlice: Identifiable, Equatable, Sendable {
    let id: String
    /// `nil` for the purchases nothing recognized yet.
    let subcategory: SpendingSubcategory?
    let total: Double
    /// Largest first.
    let merchants: [SpendingMerchantSlice]

    var isOther: Bool { subcategory == nil }

    /// The identifier of a category's "Other" slice.
    static func otherID(for category: TransactionCategory) -> String {
        "\(category.rawValue).other"
    }
}
