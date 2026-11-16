import Foundation

/// Suggests which kind of spending an unrecognized merchant is, from its
/// name alone. Used only for purchases nothing else could sort.
protocol SpendingMerchantSuggesting: Sendable {

    /// Whether suggestions can be made on this device right now.
    var isAvailable: Bool { get }

    /// The ID of the option that fits the merchant, or `nil` when none
    /// clearly does.
    func suggest(
        merchantName: String,
        category: TransactionCategory,
        options: [SpendingSubcategory]
    ) async throws -> String?
}
