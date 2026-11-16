import Foundation

/// A finer kind of spending within a ``TransactionCategory``, such as
/// Ride Share within Transportation or Groceries within Food and Dining.
///
/// Subcategories are data, not code: they are read from
/// `SpendingTaxonomy.json`, so a new kind of spending is one new entry in
/// that file. Each entry says how to recognize its purchases, from the
/// strongest signal to the weakest:
///
/// - ``merchants``: brand names that settle it, such as "doordash".
/// - ``providerCodes``: the bank feed's detailed category, such as
///   Plaid's `TRANSPORTATION_TAXIS_AND_RIDE_SHARES`.
/// - ``keywords``: generic words in a merchant's name, such as "sushi".
struct SpendingSubcategory: Codable, Hashable, Identifiable, Sendable {

    /// Stable identifier, also what a person's merchant rule stores.
    let id: String
    let name: String
    let systemImage: String
    let parent: TransactionCategory
    let providerCodes: [String]
    let merchants: [String]
    let keywords: [String]
}
