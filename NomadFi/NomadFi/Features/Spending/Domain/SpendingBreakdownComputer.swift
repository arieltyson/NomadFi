import Foundation

/// Builds a ``SpendingBreakdown`` from purchase records.
///
/// Follows the Dashboard trend card's rules, so the two always agree:
/// income and transfers are not spending, sign is ignored because import
/// formats disagree on it, and only one currency is totalled: the home
/// currency when any purchase used it, otherwise the most common one.
enum SpendingBreakdownComputer {

    static func breakdown(
        records: [SpendingRecord],
        classifier: SpendingClassifier,
        period: SpendingPeriod,
        homeCurrency: CurrencyCode,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SpendingBreakdown {
        let start = period.startDate(now: now, calendar: calendar)
        let spending = records.filter { record in
            record.date >= start && record.date <= now && record.amount != 0
                && record.category != .income && record.category != .transfer
        }
        let currency = dominantCurrency(in: spending, preferring: homeCurrency)
        let counted = spending.filter { $0.currency == currency }

        // Many purchases share a merchant, so each merchant is classified
        // once per category and bank code rather than once per purchase.
        var classified: [ClassificationKey: SpendingSubcategory?] = [:]
        var totals: [TransactionCategory: [String: MerchantTally]] = [:]

        for record in counted {
            let key = ClassificationKey(category: record.category, merchantKey: record.merchantKey, providerCode: record.providerCode)
            let subcategory: SpendingSubcategory?
            if let cached = classified[key] {
                subcategory = cached
            } else {
                subcategory = classifier.subcategory(
                    merchantKey: record.merchantKey,
                    merchantName: record.merchantName,
                    category: record.category,
                    providerCode: record.providerCode
                )
                classified[key] = subcategory
            }
            let sliceID = subcategory?.id ?? SpendingSubcategorySlice.otherID(for: record.category)
            let tallyKey = "\(sliceID)\u{1F}\(record.merchantKey)"
            totals[record.category, default: [:]][tallyKey, default: MerchantTally(sliceID: sliceID, subcategory: subcategory)]
                .add(record)
        }

        let categories = totals.map { category, tallies in
            categorySlice(category, tallies: tallies.values, classifier: classifier)
        }
        .sorted { $0.total > $1.total }

        return SpendingBreakdown(
            period: period,
            currency: currency,
            total: categories.reduce(0) { $0 + $1.total },
            categories: categories,
            otherCurrencyCount: spending.count - counted.count
        )
    }

    // MARK: - Building slices

    private static func categorySlice(
        _ category: TransactionCategory,
        tallies: some Sequence<MerchantTally>,
        classifier: SpendingClassifier
    ) -> SpendingCategorySlice {
        let subcategories = Dictionary(grouping: tallies, by: \.sliceID)
            .map { sliceID, merchants in
                SpendingSubcategorySlice(
                    id: sliceID,
                    subcategory: merchants.first?.subcategory,
                    total: merchants.reduce(0) { $0 + $1.total },
                    merchants: merchants
                        .map { tally in
                            SpendingMerchantSlice(
                                id: tally.merchantKey,
                                name: tally.latestName,
                                total: tally.total,
                                purchaseCount: tally.count,
                                ruledSubcategoryID: classifier.ruledSubcategoryID(for: tally.merchantKey)
                            )
                        }
                        .sorted { $0.total > $1.total }
                )
            }
            .sorted { lhs, rhs in
                if lhs.isOther != rhs.isOther { return rhs.isOther }
                return lhs.total > rhs.total
            }
        return SpendingCategorySlice(
            category: category,
            total: subcategories.reduce(0) { $0 + $1.total },
            subcategories: subcategories
        )
    }

    private static func dominantCurrency(
        in records: [SpendingRecord],
        preferring preferred: CurrencyCode
    ) -> CurrencyCode {
        if records.contains(where: { $0.currency == preferred }) { return preferred }
        let counts = Dictionary(records.map { ($0.currency, 1) }, uniquingKeysWith: +)
        // Ties break on the code so the result never flickers.
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.rawValue > rhs.key.rawValue
        }?.key ?? preferred
    }

    // MARK: - Accumulators

    private struct ClassificationKey: Hashable {
        let category: TransactionCategory
        let merchantKey: String
        let providerCode: String?
    }

    private struct MerchantTally {
        let sliceID: String
        let subcategory: SpendingSubcategory?
        private(set) var merchantKey = ""
        private(set) var latestName = ""
        private(set) var total: Double = 0
        private(set) var count = 0
        private var latestDate = Date.distantPast

        init(sliceID: String, subcategory: SpendingSubcategory?) {
            self.sliceID = sliceID
            self.subcategory = subcategory
        }

        mutating func add(_ record: SpendingRecord) {
            merchantKey = record.merchantKey
            total += abs(record.amount)
            count += 1
            if record.date >= latestDate {
                latestDate = record.date
                latestName = record.merchantName
            }
        }
    }
}
