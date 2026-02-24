import Foundation
import SwiftData

/// Manages ledger state including search, filtering, date grouping,
/// and the Active Card recommendation engine.
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

    // MARK: - Dependencies

    private let services: ServiceContainer

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

    /// Determines the best account to use at the user's current location.
    func updateActiveCardRecommendation(accounts: [Account]) async {
        do {
            currentCountryCode = try await services.locationService.currentCountryCode()

            guard let country = currentCountryCode else {
                recommendedAccountName = nil
                return
            }

            // Prefer accounts in the local jurisdiction (zero FX fees)
            let localAccounts = accounts.filter { $0.jurisdiction == country }
            if let best = localAccounts.min(by: { $0.foreignTransactionFeePercent < $1.foreignTransactionFeePercent }) {
                recommendedAccountName = best.name
                return
            }

            // Fall back to the account with the lowest foreign transaction fee
            let best = accounts.min { $0.foreignTransactionFeePercent < $1.foreignTransactionFeePercent }
            recommendedAccountName = best?.name
        } catch {
            recommendedAccountName = nil
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
}
