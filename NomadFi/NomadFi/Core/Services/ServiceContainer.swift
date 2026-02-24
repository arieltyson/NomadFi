// ServiceContainer.swift
// NomadFi
//
// A lightweight dependency container that provides service instances
// to view models. Uses protocol-based injection for testability.

import Foundation

/// A container holding all service dependencies for NomadFi.
///
/// View models receive this container (or individual services)
/// via initializer injection, enabling mock substitution in
/// Previews and unit tests.
///
/// - Note: Marked `@MainActor` because it is created and held by
///   the app's root view and passed to `@MainActor` view models.
@MainActor
struct ServiceContainer: Sendable {

    let exchangeRateService: any ExchangeRateService
    let financeDataService: any FinanceDataService
    let locationService: any LocationService
    let receiptScannerService: any ReceiptScannerService

    /// Creates a container with the given service implementations.
    init(
        exchangeRateService: any ExchangeRateService = MockExchangeRateService(),
        financeDataService: any FinanceDataService = MockFinanceDataService(),
        locationService: any LocationService = MockLocationService(),
        receiptScannerService: any ReceiptScannerService = MockReceiptScannerService()
    ) {
        self.exchangeRateService = exchangeRateService
        self.financeDataService = financeDataService
        self.locationService = locationService
        self.receiptScannerService = receiptScannerService
    }

    /// A container pre-configured with mock services for Previews and testing.
    static let preview = ServiceContainer()
}
