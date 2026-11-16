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

    // MARK: - Dependencies

    private var worker: SpendingBreakdownWorker?
    private var reloadTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Spending")

    init(homeCurrency: CurrencyCode, taxonomy: SpendingTaxonomy = .bundled) {
        self.homeCurrency = homeCurrency
        self.taxonomy = taxonomy
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

    private func worker(for container: ModelContainer) -> SpendingBreakdownWorker {
        if let worker { return worker }
        let created = SpendingBreakdownWorker(modelContainer: container)
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
