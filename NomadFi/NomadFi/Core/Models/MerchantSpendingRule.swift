import Foundation
import SwiftData

/// A person's choice of which kind of spending a merchant's purchases
/// are, such as "EVO is Car Share". It applies to every past and future
/// purchase from that merchant and outranks the bundled taxonomy.
///
/// CloudKit-safe: every property is defaulted and nothing is unique.
@Model
final class MerchantSpendingRule {

    /// The merchant's normalized name; see ``SpendingClassifier/merchantKey(for:)``.
    var merchantKey: String = ""
    /// A ``SpendingSubcategory/id`` from the taxonomy.
    var subcategoryID: String = ""
    var updatedAt: Date = Date.now

    init(merchantKey: String, subcategoryID: String, updatedAt: Date = .now) {
        self.merchantKey = merchantKey
        self.subcategoryID = subcategoryID
        self.updatedAt = updatedAt
    }
}
