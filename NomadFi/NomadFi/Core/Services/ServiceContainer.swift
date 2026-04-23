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
/// The default initializer wires up live service implementations
/// for production use. Use ``preview`` for SwiftUI Previews and tests.
///
/// - Note: Marked `@MainActor` because it is created and held by
///   the app's root view and passed to `@MainActor` view models.
@MainActor
struct ServiceContainer: Sendable {

    let exchangeRateService: any ExchangeRateService
    let locationService: any LocationService
    let receiptScannerService: any ReceiptScannerService

    /// Fan-out / fan-in point for every ``FinancialDataProvider`` the
    /// app knows about (manual / CSV / FinanceKit / external-aggregator
    /// seam). Replaces the earlier single-provider
    /// `FinanceDataService` abstraction so NomadFi is not hard-wired
    /// to any one upstream.
    let financialDataCoordinator: FinancialDataSyncCoordinator

    /// Creates a container with the given service implementations.
    ///
    /// Defaults to **live** implementations for production use.
    /// Pass mock services for Previews and unit tests.
    init(
        exchangeRateService: any ExchangeRateService = LiveExchangeRateService(),
        locationService: any LocationService = LiveLocationService(),
        receiptScannerService: any ReceiptScannerService = LiveReceiptScannerService(),
        financialDataCoordinator: FinancialDataSyncCoordinator = .live()
    ) {
        self.exchangeRateService = exchangeRateService
        self.locationService = locationService
        self.receiptScannerService = receiptScannerService
        self.financialDataCoordinator = financialDataCoordinator
    }

    /// A container pre-configured with mock services for Previews and testing.
    static let preview = ServiceContainer(
        exchangeRateService: MockExchangeRateService(),
        locationService: MockLocationService(),
        receiptScannerService: MockReceiptScannerService(),
        financialDataCoordinator: .preview()
    )
}
