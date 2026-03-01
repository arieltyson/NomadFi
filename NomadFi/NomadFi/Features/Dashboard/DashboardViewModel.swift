import Foundation
import OSLog
import SwiftData

/// Manages dashboard state including exchange rate fetching,
/// net worth calculations, and financial insight generation.
///
/// Works alongside `@Query` in the view: SwiftData queries provide reactive account,
/// transaction, and jurisdiction data, while this view model handles service calls,
/// currency conversions, and the ``InsightEngine`` for real-time financial intelligence.
@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - State

    var exchangeRates: [ExchangeRateSnapshot] = []
    var insights: [FinancialInsight] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    // MARK: - Dependencies

    private let services: ServiceContainer
    private var cachedRates: [ExchangeRateSnapshot] = []
    private var cachedRatesTimestamp: Date?

    /// Maximum age for cached exchange rates before they're considered stale.
    /// After this interval, cached rates are discarded on the next fetch attempt.
    private static let cacheTimeToLive: Duration = .seconds(3600) // 1 hour

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Dashboard")

    init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
    }

    // MARK: - Data Loading

    /// Fetches exchange rates for all currencies the user has across jurisdictions.
    func fetchRates(for currencies: [CurrencyCode]) async {
        guard !currencies.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let freshRates = try await PerformanceMonitor.measure(.network, name: "Fetch Exchange Rates") {
                try await services.exchangeRateService.fetchAllRates(for: currencies)
            }
            exchangeRates = freshRates
            cachedRates = freshRates
            cachedRatesTimestamp = .now
            lastUpdated = .now
            errorMessage = nil
            Self.logger.info("Exchange rates updated: \(self.exchangeRates.count) pairs")
        } catch {
            if !cachedRates.isEmpty, !isCacheExpired {
                exchangeRates = cachedRates
                errorMessage = "Using cached rates. Pull to refresh."
                Self.logger.warning("Rate fetch failed, using \(self.cachedRates.count) cached rates")
            } else {
                // Cache is either empty or stale — clear it
                cachedRates = []
                cachedRatesTimestamp = nil
                errorMessage = error.localizedDescription
                Self.logger.error("Rate fetch failed with no valid cache: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Insight Generation

    /// Generates actionable financial insights from the user's data.
    ///
    /// Replaces sample data with real calculations from the ``InsightEngine``.
    /// Falls back to sample insights when there's insufficient data.
    func generateInsights(
        transactions: [Transaction],
        accounts: [Account],
        homeCurrency: CurrencyCode
    ) {
        let generated = InsightEngine.generateInsights(
            transactions: transactions,
            accounts: accounts,
            exchangeRates: exchangeRates,
            homeCurrency: homeCurrency
        )

        // Use real insights if we have data, otherwise show helpful samples
        if generated.isEmpty && transactions.isEmpty {
            insights = FinancialInsight.samples
        } else {
            insights = generated
        }

        Self.logger.info("Dashboard insights: \(self.insights.count) (\(generated.count) from real data)")
    }

    // MARK: - Calculations

    /// Calculates the total net worth across all accounts, converted to the home currency.
    func globalNetWorth(accounts: [Account], homeCurrency: CurrencyCode) -> Double {
        accounts.reduce(0) { total, account in
            total + convertedBalance(for: account, to: homeCurrency)
        }
    }

    /// Calculates net worth for a single jurisdiction in its local currency.
    func jurisdictionNetWorth(accounts: [Account], jurisdictionCode: String) -> Double {
        accounts
            .filter { $0.jurisdiction == jurisdictionCode }
            .reduce(0) { $0 + $1.balance }
    }

    /// Converts an account's balance to the target currency using fetched rates.
    func convertedBalance(for account: Account, to targetCurrency: CurrencyCode) -> Double {
        guard let accountCurrency = account.currencyCode else { return account.balance }
        if accountCurrency == targetCurrency { return account.balance }

        guard let rate = exchangeRates.first(where: {
            $0.baseCurrency == accountCurrency && $0.targetCurrency == targetCurrency
        }) else {
            return account.balance
        }

        return account.balance * rate.rate
    }

    /// Groups accounts by jurisdiction code.
    func accountsByJurisdiction(
        accounts: [Account],
        jurisdictions: [JurisdictionProfile]
    ) -> [(profile: JurisdictionProfile, accounts: [Account])] {
        jurisdictions.compactMap { profile in
            let matching = accounts.filter { $0.jurisdiction == profile.countryCode }
            guard !matching.isEmpty else { return nil }
            return (profile: profile, accounts: matching)
        }
    }

    /// Determines the home currency from jurisdiction profiles.
    func homeCurrency(from jurisdictions: [JurisdictionProfile]) -> CurrencyCode {
        jurisdictions
            .first { $0.isHome }?
            .currencyCode ?? .usd
    }

    /// Extracts the unique set of currencies from jurisdiction profiles.
    func currencies(from jurisdictions: [JurisdictionProfile]) -> [CurrencyCode] {
        let codes = jurisdictions.compactMap(\.currencyCode)
        return Array(Set(codes)).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Cache Expiry

    /// Whether the cached exchange rates have exceeded the time-to-live threshold.
    private var isCacheExpired: Bool {
        guard let timestamp = cachedRatesTimestamp else { return true }
        return Date.now.timeIntervalSince(timestamp) > 3600 // 1 hour
    }
}
