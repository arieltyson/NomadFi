import Foundation

/// A merchant whose purchases nothing could sort, waiting for a suggestion.
struct UnrecognizedMerchant: Equatable, Sendable {
    let merchantKey: String
    let name: String
    let category: TransactionCategory
    let total: Double
}
