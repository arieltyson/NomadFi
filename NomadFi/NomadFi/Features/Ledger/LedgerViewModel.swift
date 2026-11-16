import CoreLocation
import Foundation
import OSLog
import SwiftData

/// Manages ledger state including search, filtering, date grouping,
/// and the Active Card recommendation engine.
///
/// Works alongside `@Query` in ``LedgerView``: this view model describes
/// which page of which rows to fetch, and SwiftData fetches them, filtered
/// and sorted by the store, so the ledger never loads the whole history.
@MainActor
@Observable
final class LedgerViewModel {

    // MARK: - Filter State

    /// The text in the search field, updated on every keystroke.
    var searchText: String = ""
    var selectedCategories: Set<TransactionCategory> = [] {
        didSet { resetPaging() }
    }
    var selectedJurisdiction: String? {
        didSet { resetPaging() }
    }

    /// The search the fetch applies: ``searchText`` once typing pauses.
    private(set) var appliedSearchText: String = ""

    // MARK: - Paging

    /// Rows fetched per page. One page fills several screens, so opening
    /// the ledger only ever reads a small, constant slice of the store.
    static let pageSize = 50
    /// How many rows from the end of the loaded slice the next page is
    /// requested, so it arrives before the user reaches the bottom.
    static let prefetchDistance = 15
    /// How long typing must pause before the search reaches the store.
    static let searchDebounce: Duration = .milliseconds(250)

    /// How many of the newest matching rows the ledger fetches.
    private(set) var fetchLimit = LedgerViewModel.pageSize

    // MARK: - Active Card

    var recommendedAccountName: String?
    /// Confidence in the recommended account's foreign-transaction-fee
    /// data, forwarded to the banner so it can truthfully label itself.
    var recommendedAccountFeeConfidence: SourceConfidence?
    var currentCountryCode: String?
    var isLoadingLocation = false
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Error State

    var errorMessage: String?

    // MARK: - Dependencies

    private let services: ServiceContainer
    private let locationManager = CLLocationManager()
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Ledger")

    init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
        refreshLocationAuthorizationStatus()
    }

    // MARK: - Fetching

    /// Fetches the newest page of rows matching the current filters, with
    /// filtering and sorting done by the store rather than in memory.
    var fetchDescriptor: FetchDescriptor<Transaction> {
        var descriptor = FetchDescriptor(
            predicate: filterPredicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = fetchLimit
        return descriptor
    }

    /// Matches the applied search, categories and jurisdiction, or `nil`
    /// when nothing is filtered so the store reads rows without a predicate.
    var filterPredicate: Predicate<Transaction>? {
        let search = appliedSearchText
        let categories = selectedCategories.map(\.rawValue)
        var conditions: [Predicate<Transaction>] = []

        if !search.isEmpty {
            conditions.append(#Predicate { transaction in
                transaction.merchantName.localizedStandardContains(search)
                    || transaction.notes.localizedStandardContains(search)
            })
        }
        if !categories.isEmpty {
            conditions.append(#Predicate { transaction in
                categories.contains(transaction.categoryRawValue)
            })
        }
        if let jurisdiction = selectedJurisdiction {
            conditions.append(#Predicate { transaction in
                transaction.jurisdiction == jurisdiction
            })
        }

        return conditions.reduce(nil) { combined, next in
            guard let combined else { return next }
            return #Predicate { transaction in
                combined.evaluate(transaction) && next.evaluate(transaction)
            }
        }
    }

    /// Hands the search field's text to the fetch once typing pauses, so
    /// the store is queried once per pause instead of once per keystroke.
    /// Clearing the field applies at once.
    func applySearchText() async {
        if !searchText.isEmpty {
            do {
                try await Task.sleep(for: Self.searchDebounce)
            } catch {
                return
            }
        }
        guard appliedSearchText != searchText else { return }
        appliedSearchText = searchText
        resetPaging()
    }

    /// Requests the next page once the loaded slice is full; a slice
    /// shorter than the limit means every matching row is already shown.
    func loadNextPage(loadedCount: Int) {
        guard loadedCount >= fetchLimit else { return }
        fetchLimit += Self.pageSize
    }

    /// Fetches one row, just to tell whether the ledger has any at all.
    static var anyTransactionDescriptor: FetchDescriptor<Transaction> {
        var descriptor = FetchDescriptor<Transaction>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    // MARK: - Date Grouping

    /// Groups transactions by calendar day, sorted most recent first.
    static func groupedByDate(
        _ transactions: [Transaction]
    ) -> [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        // The ledger arrives newest first, so days are contiguous: one pass
        // builds the groups without hashing every row or sorting the days.
        var groups: [(date: Date, transactions: [Transaction])] = []
        var isNewestFirst = true
        for transaction in transactions {
            let day = calendar.startOfDay(for: transaction.date)
            if let last = groups.last, last.date == day {
                groups[groups.count - 1].transactions.append(transaction)
            } else {
                if let last = groups.last, last.date < day { isNewestFirst = false }
                groups.append((date: day, transactions: [transaction]))
            }
        }
        guard !isNewestFirst else { return groups }
        // Unsorted input: fall back to grouping by day and sorting.
        return Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value) }
    }

    // MARK: - Active Card Recommendation

    /// Requests location authorization only when explicitly triggered by the user.
    ///
    /// This avoids surprise permission prompts during normal tab navigation.
    func requestLocationAuthorizationIfNeeded() {
        refreshLocationAuthorizationStatus()

        if locationAuthorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            Self.logger.info("Requested location authorization for Active Card")
            refreshLocationAuthorizationStatus()
        }
    }

    /// Refreshes the current Core Location authorization status.
    func refreshLocationAuthorizationStatus() {
        locationAuthorizationStatus = locationManager.authorizationStatus
    }

    /// Determines the best account to use at the user's current location.
    ///
    /// Prefers local accounts (zero FX fees) then falls back to the
    /// account with the lowest foreign transaction fee percentage.
    func updateActiveCardRecommendation(accounts: [Account]) async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        refreshLocationAuthorizationStatus()

        guard locationAuthorizationStatus == .authorizedWhenInUse
                || locationAuthorizationStatus == .authorizedAlways
        else {
            currentCountryCode = nil
            recommendedAccountName = nil
            recommendedAccountFeeConfidence = nil
            return
        }

        do {
            currentCountryCode = try await services.locationService.currentCountryCode()

            guard let country = currentCountryCode else {
                recommendedAccountName = nil
                recommendedAccountFeeConfidence = nil
                return
            }

            Self.logger.info("Updating Active Card for country: \(country, privacy: .private)")

            // Prefer accounts in the local jurisdiction (zero FX fees)
            let localAccounts = accounts.filter { $0.jurisdiction == country }
            if let best = localAccounts.min(by: { $0.foreignTransactionFeePercent < $1.foreignTransactionFeePercent }) {
                recommendedAccountName = best.name
                recommendedAccountFeeConfidence = SourceFreshness.effectiveConfidence(
                    for: best.foreignTransactionFeeProvenance,
                    domain: .issuerCardTerms
                )
                Self.logger.info("Recommended local account: \(best.name, privacy: .private)")
                return
            }

            // Fall back to the account with the lowest foreign transaction fee
            let best = accounts.min { $0.foreignTransactionFeePercent < $1.foreignTransactionFeePercent }
            recommendedAccountName = best?.name
            recommendedAccountFeeConfidence = best.map {
                SourceFreshness.effectiveConfidence(
                    for: $0.foreignTransactionFeeProvenance,
                    domain: .issuerCardTerms
                )
            }
        } catch {
            errorMessage = "Could not determine your location for Active Card."
            Self.logger.error("Active Card recommendation failed: \(error.localizedDescription)")
            recommendedAccountName = nil
            recommendedAccountFeeConfidence = nil
        }
    }

    // MARK: - Filter Helpers

    func toggleCategory(_ category: TransactionCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func clearFilters() {
        selectedCategories.removeAll()
        selectedJurisdiction = nil
    }

    var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || selectedJurisdiction != nil
    }

    /// Starts again from the first page when what is being matched changes.
    private func resetPaging() {
        guard fetchLimit != Self.pageSize else { return }
        fetchLimit = Self.pageSize
    }

    // MARK: - Real Cost Calculation

    /// Calculates the FX markup for a transaction.
    /// - Returns: A tuple of (fairCost, actualCost, delta) in home currency.
    func realCostBreakdown(
        for transaction: Transaction
    ) -> (fairCost: Double, actualCost: Double, delta: Double) {
        guard transaction.midMarketRate > 0, transaction.appliedExchangeRate > 0 else {
            return (fairCost: transaction.convertedAmount,
                    actualCost: transaction.convertedAmount,
                    delta: 0)
        }
        let fairCost = abs(transaction.originalAmount) * transaction.midMarketRate
        let actualCost = abs(transaction.convertedAmount)
        let delta = actualCost - fairCost
        return (fairCost: fairCost, actualCost: actualCost, delta: delta)
    }

    /// Fetches the current mid-market rate for a currency pair.
    ///
    /// Used when adding manual transactions to populate the mid-market rate field
    /// for accurate Real Cost analysis.
    func fetchMidMarketRate(
        base: CurrencyCode,
        target: CurrencyCode
    ) async -> Double? {
        do {
            let rate = try await services.exchangeRateService.fetchRate(base: base, target: target)
            Self.logger.info("Mid-market rate for \(base.rawValue, privacy: .public)/\(target.rawValue, privacy: .public): \(rate, privacy: .private)")
            return rate
        } catch {
            Self.logger.error("Failed to fetch mid-market rate: \(error.localizedDescription)")
            return nil
        }
    }
}
