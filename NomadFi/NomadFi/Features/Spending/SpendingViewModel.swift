import Foundation
import OSLog
import SwiftData

/// Drives the Spending screens: which period is shown, its breakdown, and
/// sorting a merchant into a kind of spending.
///
/// Breakdowns are built by a background ``SpendingBreakdownWorker`` and
/// kept per period, so switching back to a period is instant and the main
/// thread never totals purchases.
@MainActor
@Observable
final class SpendingViewModel {

    // MARK: - State

    let homeCurrency: CurrencyCode
    let taxonomy: SpendingTaxonomy

    /// The period being shown. Three months by default, to match the
    /// Dashboard card this screen opens from.
    var period: SpendingPeriod = .quarter {
        didSet { lastShown = breakdowns[oldValue] ?? lastShown }
    }

    /// Whether a breakdown is being built for the current period.
    private(set) var isLoading = false

    private(set) var breakdowns: [SpendingPeriod: SpendingBreakdown] = [:]

    /// The breakdown last shown, kept on screen while another period's is
    /// built so the screen never blanks.
    private var lastShown: SpendingBreakdown?

    /// The current period's breakdown, or the last one shown while it loads.
    var breakdown: SpendingBreakdown? {
        breakdowns[period] ?? lastShown
    }

    /// How long a burst of saves must settle before the breakdown is rebuilt.
    static let reloadDebounce: Duration = .milliseconds(400)

    /// How many unrecognized merchants are offered to the on-device model
    /// per visit, largest first, so the work stays brief.
    static let suggestionsPerVisit = 20

    // MARK: - Dependencies

    private let suggester: any SpendingMerchantSuggesting
    private let suggestionStore: SpendingSuggestionStore
    private var worker: SpendingBreakdownWorker?
    private var reloadTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Spending")

    init(
        homeCurrency: CurrencyCode,
        taxonomy: SpendingTaxonomy = .bundled,
        suggester: any SpendingMerchantSuggesting = FoundationModelsSpendingSuggester(),
        suggestionStore: SpendingSuggestionStore = .standard
    ) {
        self.homeCurrency = homeCurrency
        self.taxonomy = taxonomy
        self.suggester = suggester
        self.suggestionStore = suggestionStore
    }

    // MARK: - Loading

    /// Builds the current period's breakdown unless it is already built.
    func load(in container: ModelContainer) async {
        guard breakdowns[period] == nil else { return }
        await build(period, in: container)
    }

    /// Rebuilds after the store changed, once a burst of saves settles.
    /// Other periods are rebuilt when next shown.
    func scheduleReload(in container: ModelContainer) {
        reloadTask?.cancel()
        reloadTask = Task {
            do {
                try await Task.sleep(for: Self.reloadDebounce)
            } catch {
                return
            }
            await rebuildAll(in: container)
        }
    }

    /// Sorts a merchant's purchases into a subcategory for good, or with
    /// `nil` hands the merchant back to automatic sorting.
    func assign(merchantKey: String, to subcategoryID: String?, in container: ModelContainer) async {
        do {
            try await worker(for: container).setRule(merchantKey: merchantKey, subcategoryID: subcategoryID)
        } catch {
            Self.logger.error("Saving a merchant rule failed: \(error.localizedDescription, privacy: .public)")
        }
        await rebuildAll(in: container)
    }

    /// Asks the on-device model about the largest merchants nothing could
    /// sort, each only once ever, then rebuilds if any found a home. Stops
    /// when the screen goes away.
    func sortUnrecognizedMerchants(in container: ModelContainer) async {
        guard suggester.isAvailable, let breakdown = breakdowns[period] else { return }
        let worker = await worker(for: container)
        let candidates = Self.unrecognizedMerchants(
            in: breakdown,
            taxonomy: taxonomy,
            excluding: await worker.askedMerchantKeys(),
            limit: Self.suggestionsPerVisit
        )
        var answers: SpendingSuggestionStore.Suggestions = [:]
        for candidate in candidates {
            guard !Task.isCancelled else { break }
            do {
                let id = try await suggester.suggest(
                    merchantName: candidate.name,
                    category: candidate.category,
                    options: taxonomy.subcategories(of: candidate.category)
                )
                answers[candidate.merchantKey] = id ?? ""
            } catch {
                // Not remembered, so the merchant is asked about again later.
                Self.logger.error("Merchant suggestion failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        guard !answers.isEmpty else { return }
        do {
            try await worker.recordSuggestions(answers)
        } catch {
            Self.logger.error("Saving merchant suggestions failed: \(error.localizedDescription, privacy: .public)")
        }
        if answers.values.contains(where: { !$0.isEmpty }) {
            await rebuildAll(in: container)
        }
    }

    /// Merchants under a category's "Other" that the category could split
    /// into, not yet asked about, largest first.
    static func unrecognizedMerchants(
        in breakdown: SpendingBreakdown,
        taxonomy: SpendingTaxonomy,
        excluding asked: Set<String>,
        limit: Int
    ) -> [UnrecognizedMerchant] {
        var candidates: [UnrecognizedMerchant] = []
        for category in breakdown.categories where !taxonomy.subcategories(of: category.category).isEmpty {
            for other in category.subcategories where other.isOther {
                for merchant in other.merchants where merchant.ruledSubcategoryID == nil && !asked.contains(merchant.id) {
                    candidates.append(UnrecognizedMerchant(
                        merchantKey: merchant.id,
                        name: merchant.name,
                        category: category.category,
                        total: merchant.total
                    ))
                }
            }
        }
        return Array(candidates.sorted { $0.total > $1.total }.prefix(limit))
    }

    private func rebuildAll(in container: ModelContainer) async {
        breakdowns.removeAll()
        await build(period, in: container)
    }

    private func build(_ period: SpendingPeriod, in container: ModelContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let built = try await worker(for: container).breakdown(period: period, homeCurrency: homeCurrency)
            breakdowns[period] = built
            if period == self.period { lastShown = built }
        } catch {
            Self.logger.error("Spending breakdown failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func worker(for container: ModelContainer) async -> SpendingBreakdownWorker {
        if let worker { return worker }
        let created = SpendingBreakdownWorker(modelContainer: container)
        await created.useSuggestionStore(suggestionStore)
        worker = created
        return created
    }

    // MARK: - Presentation

    /// The kinds a merchant in this category can be sorted into.
    func choices(for category: TransactionCategory) -> [SpendingSubcategory] {
        taxonomy.subcategories(of: category)
    }

    /// One slice per category, largest first.
    static func categorySlices(of breakdown: SpendingBreakdown) -> [SpendingChartSlice] {
        breakdown.categories.enumerated().map { rank, slice in
            SpendingChartSlice(
                id: slice.category.rawValue,
                name: slice.category.displayName,
                systemImage: slice.category.systemImage,
                total: slice.total,
                colorRank: rank,
                share: share(slice.total, of: breakdown.total)
            )
        }
    }

    /// One slice per subcategory, largest first, with "Other" last.
    static func subcategorySlices(of category: SpendingCategorySlice) -> [SpendingChartSlice] {
        category.subcategories.enumerated().map { rank, slice in
            SpendingChartSlice(
                id: slice.id,
                name: slice.subcategory?.name ?? String(localized: "Other"),
                systemImage: slice.subcategory?.systemImage ?? "ellipsis.circle",
                total: slice.total,
                colorRank: slice.isOther ? nil : rank,
                share: share(slice.total, of: category.total)
            )
        }
    }

    /// The slice under a point on a ring chart, where `value` runs from
    /// zero to the sum of every slice, in the slices' order.
    static func sliceID(atAngleValue value: Double, in slices: [SpendingChartSlice]) -> String? {
        var upperBound = 0.0
        for slice in slices {
            upperBound += slice.total
            if value <= upperBound { return slice.id }
        }
        return slices.last?.id
    }

    private static func share(_ part: Double, of whole: Double) -> Double {
        whole > 0 ? part / whole : 0
    }
}
