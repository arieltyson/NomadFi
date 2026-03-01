import CoreLocation
import Foundation
import OSLog
import SwiftData

/// Manages ledger state including search, filtering, date grouping,
/// FX waste aggregation, and the Active Card recommendation engine.
///
/// Works alongside `@Query` in ``LedgerView``: SwiftData queries provide
/// reactive transaction data, while this view model handles filtering,
/// grouping, service calls, and derived intelligence.
@MainActor
@Observable
final class LedgerViewModel {

    // MARK: - Filter State

    var searchText: String = ""
    var selectedCategories: Set<TransactionCategory> = []
    var selectedJurisdiction: String?

    // MARK: - Active Card

    var recommendedAccountName: String?
    var currentCountryCode: String?
    var isLoadingLocation = false

    // MARK: - Error State

    var errorMessage: String?

    // MARK: - FX Intelligence

    var weeklyFXWaste: Double = 0
    var monthlyFXWaste: Double = 0
    var crossBorderCountThisWeek: Int = 0

    // MARK: - Dependencies

    private let services: ServiceContainer
    private let locationManager = CLLocationManager()
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Ledger")

    init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
    }

    // MARK: - Filtering

    /// Applies search text, category, and jurisdiction filters to a transaction list.
    func filteredTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in
            let matchesSearch = searchText.isEmpty
                || transaction.merchantName.localizedStandardContains(searchText)
                || transaction.notes.localizedStandardContains(searchText)

            let matchesCategory = selectedCategories.isEmpty
                || (transaction.category.map { selectedCategories.contains($0) } ?? false)

            let matchesJurisdiction = selectedJurisdiction == nil
                || transaction.jurisdiction == selectedJurisdiction

            return matchesSearch && matchesCategory && matchesJurisdiction
        }
    }

    // MARK: - Date Grouping

    /// Groups transactions by calendar day, sorted most recent first.
    func groupedByDate(
        _ transactions: [Transaction]
    ) -> [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value) }
    }

    // MARK: - Active Card Recommendation

    /// Requests location authorization if not yet determined.
    ///
    /// Called when the Ledger tab appears. Location is used to recommend
    /// the best payment card based on the user's country.
    func requestLocationAuthorizationIfNeeded() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            Self.logger.info("Requested location authorization for Active Card")
        }
    }

    /// Determines the best account to use at the user's current location.
    ///
    /// Prefers local accounts (zero FX fees) then falls back to the
    /// account with the lowest foreign transaction fee percentage.
    func updateActiveCardRecommendation(accounts: [Account]) async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        do {
            currentCountryCode = try await services.locationService.currentCountryCode()

            guard let country = currentCountryCode else {
                recommendedAccountName = nil
                return
            }

            Self.logger.info("Updating Active Card for country: \(country, privacy: .private)")

            // Prefer accounts in the local jurisdiction (zero FX fees)
            let localAccounts = accounts.filter { $0.jurisdiction == country }
            if let best = localAccounts.min(by: { $0.foreignTransactionFeePercent < $1.foreignTransactionFeePercent }) {
                recommendedAccountName = best.name
                Self.logger.info("Recommended local account: \(best.name, privacy: .private)")
                return
            }

            // Fall back to the account with the lowest foreign transaction fee
            let best = accounts.min { $0.foreignTransactionFeePercent < $1.foreignTransactionFeePercent }
            recommendedAccountName = best?.name
        } catch {
            errorMessage = "Could not determine your location for Active Card."
            Self.logger.error("Active Card recommendation failed: \(error.localizedDescription)")
            recommendedAccountName = nil
        }
    }

    // MARK: - FX Intelligence

    /// Updates all FX waste metrics from the transaction history.
    func updateFXIntelligence(transactions: [Transaction]) {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now

        weeklyFXWaste = InsightEngine.totalFXWaste(transactions: transactions, since: oneWeekAgo)
        monthlyFXWaste = InsightEngine.totalFXWaste(transactions: transactions, since: oneMonthAgo)
        crossBorderCountThisWeek = InsightEngine.crossBorderTransactionCount(
            transactions: transactions,
            since: oneWeekAgo
        )

        Self.logger.info(
            "FX intelligence updated — weekly waste: \(self.weeklyFXWaste, privacy: .private), monthly: \(self.monthlyFXWaste, privacy: .private)"
        )
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
