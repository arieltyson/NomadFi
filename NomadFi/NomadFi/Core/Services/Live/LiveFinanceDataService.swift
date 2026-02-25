// LiveFinanceDataService.swift
// NomadFi
//
// Wraps Apple's FinanceKit framework for on-device financial data access.
// Gracefully degrades when FinanceKit is unavailable (most devices).

import FinanceKit
import Foundation
import OSLog

/// Live implementation of ``FinanceDataService`` using Apple's FinanceKit.
///
/// FinanceKit only works with Apple Card/Cash in the US and selected UK banks.
/// For most international students, this will report `.unavailable` and the app
/// falls back seamlessly to manual account/transaction entry.
///
/// - Important: Requires the `com.apple.developer.finance-kit` entitlement
///   and a real device with supported financial accounts. Authorization checks
///   are fully implemented. Data fetching (accounts, transactions) is stubbed
///   behind runtime availability checks and will be refined once the entitlement
///   is provisioned and testable on a real device.
struct LiveFinanceDataService: FinanceDataService {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "FinanceData")

    // MARK: - Authorization

    func checkAuthorization() async -> FinanceDataAuthorizationStatus {
        guard FinanceStore.isDataAvailable(.financialData) else {
            Self.logger.info("FinanceKit data not available on this device")
            return .unavailable
        }

        do {
            let status = try await FinanceStore.shared.authorizationStatus()
            return mapAuthorizationStatus(status)
        } catch {
            Self.logger.error("Authorization check failed: \(error.localizedDescription, privacy: .public)")
            return .unavailable
        }
    }

    func requestAuthorization() async throws -> FinanceDataAuthorizationStatus {
        guard FinanceStore.isDataAvailable(.financialData) else {
            return .unavailable
        }

        do {
            let status = try await FinanceStore.shared.requestAuthorization()
            Self.logger.info("FinanceKit authorization granted: \(String(describing: status), privacy: .public)")
            return mapAuthorizationStatus(status)
        } catch {
            Self.logger.error("FinanceKit authorization failed: \(error.localizedDescription, privacy: .public)")
            throw FinanceDataServiceError.authorizationDenied
        }
    }

    // MARK: - Data Fetching

    func fetchAccounts() async throws -> [AccountSnapshot] {
        guard FinanceStore.isDataAvailable(.financialData) else {
            throw FinanceDataServiceError.dataUnavailable
        }

        // FinanceKit account fetching requires the com.apple.developer.finance-kit
        // entitlement and a real device with supported financial institutions.
        // Once provisioned, this will query FinanceStore.shared.accounts(query:)
        // and map each FinanceKit.Account to an AccountSnapshot.
        Self.logger.info("FinanceKit account fetching awaiting entitlement provisioning")
        throw FinanceDataServiceError.dataUnavailable
    }

    func fetchTransactions(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [TransactionSnapshot] {
        guard FinanceStore.isDataAvailable(.financialData) else {
            throw FinanceDataServiceError.dataUnavailable
        }

        // FinanceKit transaction fetching requires the com.apple.developer.finance-kit
        // entitlement. Once provisioned, this will query FinanceStore.shared.transactions(query:),
        // filter by account ID and date range, and map FinanceKit.Transaction to
        // TransactionSnapshot with proper currency and merchant extraction.
        Self.logger.info("FinanceKit transaction fetching awaiting entitlement provisioning")
        throw FinanceDataServiceError.dataUnavailable
    }
}

// MARK: - Mapping Helpers

private extension LiveFinanceDataService {

    func mapAuthorizationStatus(_ status: FinanceKit.AuthorizationStatus) -> FinanceDataAuthorizationStatus {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .unavailable
        }
    }
}
