import Foundation

/// What one merchant took within a subcategory.
struct SpendingMerchantSlice: Identifiable, Equatable, Sendable {
    /// The merchant key, shared by every purchase from the merchant.
    let id: String
    /// The name from the merchant's most recent purchase.
    let name: String
    let total: Double
    let purchaseCount: Int
    /// The subcategory the person chose for this merchant, if they did;
    /// `nil` means it is sorted automatically.
    let ruledSubcategoryID: String?
}
