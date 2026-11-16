import Foundation

/// The few facts about one purchase the breakdown needs, copied out of a
/// `Transaction` so the work can run on plain values.
struct SpendingRecord: Sendable {
    let merchantKey: String
    let merchantName: String
    let category: TransactionCategory
    /// The bank feed's detailed category code, when the purchase came
    /// from a linked bank.
    let providerCode: String?
    let amount: Double
    let currency: CurrencyCode
    let date: Date
}
