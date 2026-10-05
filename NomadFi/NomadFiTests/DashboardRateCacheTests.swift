// DashboardRateCacheTests.swift
// NomadFi
//
// Pins that returning to the Dashboard reuses fresh exchange rates
// instead of hitting the network on every tab switch.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct DashboardRateCacheTests {

    @Test("A fresh cache for the same currencies skips the network")
    func freshCacheSkipsNetwork() async {
        let service = CountingExchangeRateService()
        let viewModel = makeViewModel(service: service)

        await viewModel.fetchRates(for: [.cad, .usd])
        await viewModel.fetchRates(for: [.cad, .usd])

        #expect(await service.fetchCount == 1)
        #expect(!viewModel.exchangeRates.isEmpty)
    }

    @Test("Pull to refresh fetches even when the cache is fresh")
    func forcedRefreshFetches() async {
        let service = CountingExchangeRateService()
        let viewModel = makeViewModel(service: service)

        await viewModel.fetchRates(for: [.cad, .usd])
        await viewModel.fetchRates(for: [.cad, .usd], force: true)

        #expect(await service.fetchCount == 2)
    }

    @Test("A changed currency set fetches again")
    func changedCurrenciesFetch() async {
        let service = CountingExchangeRateService()
        let viewModel = makeViewModel(service: service)

        await viewModel.fetchRates(for: [.cad, .usd])
        await viewModel.fetchRates(for: [.cad, .ttd, .usd])

        #expect(await service.fetchCount == 2)
    }

    private func makeViewModel(service: CountingExchangeRateService) -> DashboardViewModel {
        DashboardViewModel(
            services: ServiceContainer(
                exchangeRateService: service,
                locationService: MockLocationService(),
                receiptScannerService: MockReceiptScannerService(),
                financialDataCoordinator: .preview()
            )
        )
    }
}

/// Counts network-shaped fetches, answering instantly with sample rates.
private actor CountingExchangeRateService: ExchangeRateService {

    private(set) var fetchCount = 0
    private let sample = MockExchangeRateService(simulatedDelay: .zero)

    func fetchRate(base: CurrencyCode, target: CurrencyCode) async throws -> Double {
        try await sample.fetchRate(base: base, target: target)
    }

    func fetchAllRates(for currencies: [CurrencyCode]) async throws -> [ExchangeRateSnapshot] {
        fetchCount += 1
        return try await sample.fetchAllRates(for: currencies)
    }
}
