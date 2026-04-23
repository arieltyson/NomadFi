// FinanceKitFinancialDataProvider.swift
// NomadFi
//
// Adapter between Apple's on-device FinanceKit framework and NomadFi's
// provider-neutral contract. The adapter is intentionally additive:
// when FinanceKit is not available (most devices, most regions) the
// coordinator falls back to the manual and CSV providers without
// breaking the core experience.
//
// Current shape:
// - Availability / authorization / requestAuthorization are fully
//   wired to FinanceKit primitives.
// - Snapshot fetches return empty arrays until Apple provisions the
//   managed `com.apple.developer.finance-kit` entitlement. The typed
//   mapping helpers are in place so the remaining work once the
//   entitlement lands is limited to calling `FinanceStore.shared`
//   query APIs and piping the results through the mappers.
// - Background-update integration is declared as a seam
//   (`scheduleBackgroundUpdates`) so the coordinator can register a
//   refresh hook once Apple exposes its delivery entitlement without
//   restructuring this adapter.
//
// Research notes (factual, not marketing):
// - FinanceKit data stays on-device; Apple never sees it.
// - US coverage is Apple Card, Apple Cash, and Apple Savings.
// - UK coverage is a selected set of open-banking institutions.
// - Coverage does not generalise to arbitrary issuers — broad market
//   coverage may require an additional provider later, which is why
//   the external-aggregator seam exists.

import FinanceKit
import Foundation
import OSLog

/// Live adapter that wraps Apple's FinanceKit framework.
///
/// The adapter is `struct`-based and `Sendable`; it holds no state and
/// is safe for the coordinator to instantiate per-sync.
struct FinanceKitFinancialDataProvider: FinancialDataProvider {

    let kind: FinancialDataProviderKind = .financeKit

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.FinanceKit"
    )

    // MARK: - Availability / authorization

    func availability() async -> FinancialDataProviderAvailability {
        guard FinanceStore.isDataAvailable(.financialData) else {
            Self.logger.info("FinanceKit data class not available on this device")
            return .unavailable(reason: .notSupportedOnDevice)
        }
        return .available
    }

    func authorizationStatus() async -> FinancialDataAuthorizationStatus {
        guard FinanceStore.isDataAvailable(.financialData) else {
            return .unavailable
        }
        do {
            let status = try await FinanceStore.shared.authorizationStatus()
            return Self.map(status)
        } catch {
            Self.logger.error(
                "FinanceKit authorization status check failed: \(error.localizedDescription, privacy: .public)"
            )
            return .unavailable
        }
    }

    func requestAuthorization() async throws -> FinancialDataAuthorizationStatus {
        guard FinanceStore.isDataAvailable(.financialData) else {
            throw FinancialDataProviderError.providerUnavailable(.notSupportedOnDevice)
        }
        do {
            let status = try await FinanceStore.shared.requestAuthorization()
            Self.logger.info(
                "FinanceKit authorization request resolved: \(String(describing: status), privacy: .public)"
            )
            return Self.map(status)
        } catch {
            Self.logger.error(
                "FinanceKit authorization request failed: \(error.localizedDescription, privacy: .public)"
            )
            throw FinancialDataProviderError.authorizationDenied
        }
    }

    // MARK: - Connections

    func connections() async -> [FinancialDataConnection] {
        let availability = await availability()
        switch availability {
        case .unavailable(let reason):
            return [
                FinancialDataConnection(
                    id: "finance-kit",
                    providerKind: .financeKit,
                    displayName: "Apple FinanceKit",
                    status: .unavailable(reason: reason)
                )
            ]
        case .available, .availableNoConnections:
            let status = await authorizationStatus()
            let connectionStatus: FinancialDataConnectionStatus
            switch status {
            case .authorized: connectionStatus = .connected
            case .notDetermined: connectionStatus = .authorizationRequired
            case .denied: connectionStatus = .authorizationRequired
            case .unavailable: connectionStatus = .unavailable(reason: .notSupportedOnDevice)
            }
            return [
                FinancialDataConnection(
                    id: "finance-kit",
                    providerKind: .financeKit,
                    displayName: "Apple FinanceKit",
                    status: connectionStatus
                )
            ]
        }
    }

    // MARK: - Snapshots

    func fetchAccountSnapshots() async throws -> [FinancialAccountSnapshot] {
        try await ensureAuthorized()

        // Once the `com.apple.developer.finance-kit` managed entitlement is
        // provisioned, this becomes:
        //
        //     let accounts = try await FinanceStore.shared.accounts(
        //         query: AccountQuery()
        //     )
        //     return accounts.map(Self.map(financeKitAccount:))
        //
        // Until then, returning an empty array keeps the coordinator's
        // fallback path exercised and avoids throwing in the success
        // code path.
        Self.logger.info("FinanceKit account fetch no-op; awaiting entitlement provisioning")
        return []
    }

    func fetchTransactionSnapshots(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [FinancialTransactionSnapshot] {
        try await ensureAuthorized()

        // Once entitled:
        //
        //     let predicate = #Predicate<FinanceKit.Transaction> {
        //         $0.accountID.uuidString == accountID &&
        //         $0.transactionDate >= startDate &&
        //         $0.transactionDate <= endDate
        //     }
        //     let results = try await FinanceStore.shared.transactions(
        //         query: TransactionQuery(predicate: predicate)
        //     )
        //     return results.map(Self.map(financeKitTransaction:))
        Self.logger.info("FinanceKit transaction fetch no-op; awaiting entitlement provisioning")
        return []
    }

    // MARK: - Background update seam

    /// Stub for a future `BGTaskScheduler` / FinanceKit background
    /// delivery hook. Not called yet — documented here so the
    /// coordinator has a single, known place to register refresh
    /// once Apple's entitlement unlocks delivery.
    func scheduleBackgroundUpdates() async {
        // Intentionally empty today. When the entitlement lands, this
        // registers a background task that kicks a sync through the
        // coordinator and posts a local notification only when data
        // changes — never silently.
    }

    // MARK: - Private helpers

    private func ensureAuthorized() async throws {
        switch await availability() {
        case .unavailable(let reason):
            throw FinancialDataProviderError.providerUnavailable(reason)
        case .available, .availableNoConnections:
            break
        }
        switch await authorizationStatus() {
        case .authorized: break
        case .denied: throw FinancialDataProviderError.authorizationDenied
        case .notDetermined, .unavailable:
            throw FinancialDataProviderError.providerUnavailable(.entitlementNotProvisioned)
        }
    }

    /// Typed projection from FinanceKit's enum to the provider-neutral
    /// authorization enum. Kept as a pure static so tests can assert
    /// against every branch without a device.
    static func map(_ status: FinanceKit.AuthorizationStatus) -> FinancialDataAuthorizationStatus {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .unavailable
        }
    }
}
