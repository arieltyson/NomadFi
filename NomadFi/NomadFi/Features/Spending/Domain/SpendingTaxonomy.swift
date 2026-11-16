import Foundation
import OSLog

/// The full set of ``SpendingSubcategory`` entries, grouped by category.
struct SpendingTaxonomy: Sendable {

    let subcategories: [SpendingSubcategory]

    private let byID: [String: SpendingSubcategory]
    private let byParent: [TransactionCategory: [SpendingSubcategory]]

    init(subcategories: [SpendingSubcategory]) {
        self.subcategories = subcategories
        byID = Dictionary(subcategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        byParent = Dictionary(grouping: subcategories, by: \.parent)
    }

    /// The subcategories a category splits into, in the file's order.
    func subcategories(of category: TransactionCategory) -> [SpendingSubcategory] {
        byParent[category] ?? []
    }

    func subcategory(id: String) -> SpendingSubcategory? {
        byID[id]
    }

    // MARK: - Bundled

    /// The taxonomy shipped in `SpendingTaxonomy.json`. Empty if the file
    /// is missing or malformed, in which case every purchase stays under
    /// its category's "Other" until it is sorted by hand.
    static let bundled: SpendingTaxonomy = {
        let logger = Logger(subsystem: "com.nomadfi.app", category: "SpendingTaxonomy")
        guard let url = Bundle.main.url(forResource: "SpendingTaxonomy", withExtension: "json") else {
            logger.error("SpendingTaxonomy.json is missing from the bundle")
            return SpendingTaxonomy(subcategories: [])
        }
        do {
            return try decode(Data(contentsOf: url))
        } catch {
            logger.error("SpendingTaxonomy.json could not be read: \(error.localizedDescription, privacy: .public)")
            return SpendingTaxonomy(subcategories: [])
        }
    }()

    /// Decodes a taxonomy file's contents.
    static func decode(_ data: Data) throws -> SpendingTaxonomy {
        try SpendingTaxonomy(subcategories: JSONDecoder().decode(File.self, from: data).subcategories)
    }

    private struct File: Decodable {
        let subcategories: [SpendingSubcategory]
    }
}
