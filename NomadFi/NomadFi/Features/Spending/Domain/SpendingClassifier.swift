import Foundation

/// Decides which ``SpendingSubcategory`` a purchase belongs to.
///
/// Signals are tried from the most to the least trustworthy:
///
/// 1. The person's own rule for the merchant: what they said always wins.
/// 2. A brand name from the taxonomy: "DoorDash" is delivery even though
///    bank feeds file it under restaurants.
/// 3. The bank feed's detailed category code.
/// 4. A generic word in the merchant's name.
///
/// A purchase only ever lands in a subcategory of its own category, so
/// "Uber" is Ride Share under Transportation and Delivery under Food and
/// Dining. When nothing matches, it returns `nil` and the purchase stays
/// under its category's "Other", where one tap sorts the merchant for good.
struct SpendingClassifier: Sendable {

    let taxonomy: SpendingTaxonomy

    /// Merchant key → subcategory ID, from the person's own choices.
    private let merchantRules: [String: String]
    private let matchers: [TransactionCategory: Matchers]

    init(taxonomy: SpendingTaxonomy, merchantRules: [String: String] = [:]) {
        self.taxonomy = taxonomy
        self.merchantRules = merchantRules
        matchers = Dictionary(
            uniqueKeysWithValues: TransactionCategory.allCases.map { category in
                (category, Matchers(taxonomy.subcategories(of: category)))
            }
        )
    }

    /// The subcategory for one purchase, or `nil` for "Other".
    ///
    /// - Parameters:
    ///   - merchantKey: The merchant's normalized name, which rules are
    ///     keyed by; see ``merchantKey(for:)``.
    ///   - merchantName: The name as the bank or person wrote it, which
    ///     brands and words are matched in. It keeps processor prefixes
    ///     such as "AMZN*" that normalizing strips.
    ///   - category: The purchase's category.
    ///   - providerCode: The bank feed's detailed category, when known.
    func subcategory(
        merchantKey: String,
        merchantName: String,
        category: TransactionCategory,
        providerCode: String?
    ) -> SpendingSubcategory? {
        if let ruleID = merchantRules[merchantKey],
           let ruled = taxonomy.subcategory(id: ruleID),
           ruled.parent == category {
            return ruled
        }
        guard let matchers = matchers[category] else { return nil }
        let words = Self.wordString(merchantName)
        return matchers.merchant(in: words)
            ?? providerCode.flatMap { matchers.byProviderCode[$0] }
            ?? matchers.keyword(in: words)
    }

    /// The key purchases from one merchant share, used for rules and for
    /// grouping: the import-time normalized name when there is one.
    static func merchantKey(for transaction: Transaction) -> String {
        if let normalized = transaction.normalizedMerchantName, !normalized.isEmpty {
            return normalized
        }
        return MerchantNormalizer.normalize(transaction.merchantName)
    }

    // MARK: - Matching

    /// Lowercased words separated by single spaces and padded with one on
    /// each side, so " evo " matches "EVO CAR SHARE" but not "CHEVRON".
    static func wordString(_ text: String) -> String {
        let words = text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
        return " \(words.joined(separator: " ")) "
    }

    /// One category's lookup tables, built once per classifier.
    private struct Matchers: Sendable {

        /// Longest phrase first, so "uber eats" is tried before "uber".
        let merchants: [(phrase: String, subcategory: SpendingSubcategory)]
        let keywords: [(phrase: String, subcategory: SpendingSubcategory)]
        let byProviderCode: [String: SpendingSubcategory]

        init(_ subcategories: [SpendingSubcategory]) {
            merchants = Self.phrases(subcategories, \.merchants)
            keywords = Self.phrases(subcategories, \.keywords)
            byProviderCode = Dictionary(
                subcategories.flatMap { subcategory in
                    subcategory.providerCodes.map { ($0, subcategory) }
                },
                uniquingKeysWith: { first, _ in first }
            )
        }

        func merchant(in words: String) -> SpendingSubcategory? {
            merchants.first { words.contains($0.phrase) }?.subcategory
        }

        func keyword(in words: String) -> SpendingSubcategory? {
            keywords.first { words.contains($0.phrase) }?.subcategory
        }

        private static func phrases(
            _ subcategories: [SpendingSubcategory],
            _ list: KeyPath<SpendingSubcategory, [String]>
        ) -> [(phrase: String, subcategory: SpendingSubcategory)] {
            subcategories
                .flatMap { subcategory in
                    subcategory[keyPath: list].map { (phrase: SpendingClassifier.wordString($0), subcategory: subcategory) }
                }
                .filter { $0.phrase.count > 2 }
                .sorted { $0.phrase.count > $1.phrase.count }
        }
    }
}
