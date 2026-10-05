// ExchangeRatesViewModelTests.swift
// NomadFi
//
// Pins caching, refresh and the trust summary of Tools → Exchange
// Rates.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct ExchangeRatesViewModelTests {

    @Test("Fresh rates for the same currencies are reused; pull to refresh fetches")
    func cachesUntilForced() async {
        let service = StubExchangeRateService()
        let viewModel = ExchangeRatesViewModel(service: service)

        await viewModel.load(for: [.cad, .usd])
        await viewModel.load(for: [.cad, .usd])
        #expect(await service.fetchCount == 1)

        await viewModel.load(for: [.cad, .usd], force: true)
        #expect(await service.fetchCount == 2)
    }

    @Test("A single currency has no pairs and fetches nothing")
    func singleCurrencyHasNoPairs() async {
        let service = StubExchangeRateService()
        let viewModel = ExchangeRatesViewModel(service: service)

        await viewModel.load(for: [.usd])

        #expect(viewModel.rates.isEmpty)
        #expect(await service.fetchCount == 0)
    }

    @Test("Rates have one identity per pair")
    func ratesHaveUniquePairIdentities() async {
        let viewModel = ExchangeRatesViewModel(service: StubExchangeRateService())

        await viewModel.load(for: [.cad, .ttd, .usd])

        let ids = viewModel.rates.map(\.id)
        #expect(ids.count == 6)
        #expect(Set(ids).count == ids.count)
    }

    @Test("A failed first load reports failure; a failed refresh keeps the rates")
    func failureKeepsShownRates() async {
        let service = StubExchangeRateService()
        let viewModel = ExchangeRatesViewModel(service: service)

        await service.setFailing(true)
        await viewModel.load(for: [.cad, .usd])
        #expect(viewModel.loadFailed)

        await service.setFailing(false)
        await viewModel.load(for: [.cad, .usd])
        #expect(!viewModel.loadFailed)

        await service.setFailing(true)
        await viewModel.load(for: [.cad, .usd], force: true)
        #expect(!viewModel.loadFailed)
        #expect(!viewModel.rates.isEmpty)
    }

    @Test("Sample rates carry their confidence and are fresh")
    func trustSummary() async {
        let viewModel = ExchangeRatesViewModel(service: StubExchangeRateService())

        await viewModel.load(for: [.cad, .usd])

        #expect(viewModel.confidence == viewModel.rates.first?.sourceProvenance.confidence)
        #expect(!viewModel.needsRefresh)
    }
}

/// Answers instantly with sample rates, counting fetches.
private actor StubExchangeRateService: ExchangeRateService {

    private(set) var fetchCount = 0
    private var isFailing = false
    private let sample = MockExchangeRateService(simulatedDelay: .zero)

    func setFailing(_ failing: Bool) {
        isFailing = failing
    }

    func fetchRate(base: CurrencyCode, target: CurrencyCode) async throws -> Double {
        try await sample.fetchRate(base: base, target: target)
    }

    func fetchAllRates(for currencies: [CurrencyCode]) async throws -> [ExchangeRateSnapshot] {
        fetchCount += 1
        if isFailing { throw ExchangeRateServiceError.networkUnavailable }
        return try await sample.fetchAllRates(for: currencies)
    }
}
