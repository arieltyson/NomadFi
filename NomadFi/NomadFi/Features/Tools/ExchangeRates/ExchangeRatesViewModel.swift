// ExchangeRatesViewModel.swift
// NomadFi
//
// Loads the exchange rates between the person's currencies for the
// Tools → Exchange Rates page.

import Foundation
import OSLog

/// Loads exchange rates for the person's currencies and describes how
/// far to trust them.
@MainActor
@Observable
final class ExchangeRatesViewModel {

    // MARK: - State

    private(set) var rates: [ExchangeRateSnapshot] = []
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    // MARK: - Dependencies

    private let service: any ExchangeRateService
    private var loadedCurrencies: Set<CurrencyCode> = []

    /// The rate provider's site, credited wherever rates are shown, as
    /// its free terms require.
    static let attributionURL = URL(string: "https://www.exchangerate-api.com")

    /// Rates younger than this are reused rather than refetched.
    private static let cacheTimeToLive: Duration = .seconds(3600)

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "ExchangeRates")

    init(service: any ExchangeRateService = ServiceContainer().exchangeRateService) {
        self.service = service
    }

    // MARK: - Loading

    /// Loads rates between `currencies`, reusing fresh ones unless
    /// `force` is set — for an explicit pull to refresh.
    func load(for currencies: [CurrencyCode], force: Bool = false) async {
        guard currencies.count > 1 else {
            rates = []
            return
        }
        guard force || !hasFreshRates(for: currencies) else { return }

        isLoading = rates.isEmpty
        defer { isLoading = false }

        do {
            let fresh = try await service.fetchAllRates(for: currencies)
            rates = fresh.sorted { $0.id < $1.id }
            lastUpdated = .now
            loadedCurrencies = Set(currencies)
            loadFailed = false
        } catch is CancellationError {
        } catch {
            // Keep any rates already on screen; fail visibly only
            // when there is nothing to show.
            loadFailed = rates.isEmpty
            Self.logger.error("Rate fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The distinct currencies across the person's jurisdictions.
    static func currencies(from jurisdictions: [JurisdictionProfile]) -> [CurrencyCode] {
        Set(jurisdictions.compactMap(\.currencyCode)).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Trust

    /// One confidence for the whole list: the shared one when every
    /// rate agrees, otherwise the weaker "indicative", so the list
    /// never overstates its data.
    var confidence: SourceConfidence? {
        guard let first = rates.first?.sourceProvenance.confidence else { return nil }
        return rates.allSatisfy { $0.sourceProvenance.confidence == first } ? first : .indicative
    }

    /// Whether any rate is past its freshness window.
    var needsRefresh: Bool {
        rates.contains {
            SourceFreshness.status(for: $0.sourceProvenance, domain: .liveFXMarketData) == .stale
        }
    }

    // MARK: - Private

    private func hasFreshRates(for currencies: [CurrencyCode]) -> Bool {
        guard let lastUpdated, !rates.isEmpty, loadedCurrencies == Set(currencies) else {
            return false
        }
        return Date.now.timeIntervalSince(lastUpdated) < Self.cacheTimeToLive / .seconds(1)
    }
}
