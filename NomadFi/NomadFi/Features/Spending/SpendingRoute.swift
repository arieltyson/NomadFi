import Foundation

/// Opens the Spending screen from the Dashboard's trend card.
struct SpendingRoute: Hashable {
    /// The currency the Dashboard shows, which the breakdown prefers.
    let homeCurrency: CurrencyCode
}
