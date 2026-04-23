// FinanceKitFinancialDataProvider.swift
// NomadFi
//
// Adapter between Apple's on-device FinanceKit framework and NomadFi's
// provider-neutral contract. The adapter is additive: when FinanceKit
// is not available (most devices, most regions, or before Apple has
// provisioned the managed entitlement) the coordinator falls back to
// the manual and CSV providers without breaking the core experience.
//
// Source references (Apple docs + the local Xcode 26.4 swiftinterface):
// - `FinanceStore.isDataAvailable(.financialData)` is the device /
//   platform gate.
// - `FinanceStore.shared.authorizationStatus()` /
//   `requestAuthorization()` are gated on the managed
//   `com.apple.developer.financekit` entitlement; they throw
//   `FinanceError.dataRestricted(.financialData)` when that
//   entitlement is missing or when the system blocks access.
// - `FinanceStore.shared.accounts(query:)`,
//   `accountBalances(query:)`, and `transactions(query:)` are the
//   three snapshot fetch surfaces NomadFi needs. All three live on
//   the main `FinanceStore` and return `Sendable` row types.
// - `enableBackgroundDelivery(for:frequency:)` + a
//   `BackgroundDeliveryExtension` are the official path for
//   background updates on iOS 26+. Not wired up in this slice —
//   background delivery requires a separate app extension and more
//   entitlement work; the adapter exposes the seam without
//   activating it.

import FinanceKit
import Foundation
import OSLog

/// Live adapter that wraps Apple's FinanceKit framework.
///
/// `struct`-based and `Sendable`; the coordinator instantiates it
/// per-sync. All framework state lives in `FinanceStore.shared`.
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
        } catch let error as FinanceError {
            Self.logger.error(
                "FinanceKit authorization status errored: \(String(describing: error), privacy: .public)"
            )
            return Self.authorizationStatus(for: error)
        } catch {
            Self.logger.error(
                "FinanceKit authorization status unknown error: \(error.localizedDescription, privacy: .public)"
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
        } catch let error as FinanceError {
            Self.logger.error(
                "FinanceKit authorization request errored: \(String(describing: error), privacy: .public)"
            )
            throw Self.providerError(for: error)
        } catch {
            Self.logger.error(
                "FinanceKit authorization request unknown error: \(error.localizedDescription, privacy: .public)"
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
            case .notDetermined, .denied: connectionStatus = .authorizationRequired
            case .unavailable: connectionStatus = .unavailable(reason: .entitlementNotProvisioned)
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

        do {
            let financeAccounts = try await FinanceStore.shared.accounts(
                query: AccountQuery()
            )
            if financeAccounts.isEmpty {
                Self.logger.info("FinanceKit returned zero accounts under current authorization")
                return []
            }
            let balances = try await FinanceStore.shared.accountBalances(
                query: AccountBalanceQuery()
            )
            let balancesByAccount = Dictionary(
                grouping: balances,
                by: { $0.accountID }
            )
            var snapshots: [FinancialAccountSnapshot] = []
            snapshots.reserveCapacity(financeAccounts.count)
            for account in financeAccounts {
                let input = Self.accountInput(
                    from: account,
                    balances: balancesByAccount[account.id] ?? []
                )
                if let snapshot = FinanceKitSnapshotMapper.mapAccount(input) {
                    snapshots.append(snapshot)
                } else {
                    Self.logger.info(
                        "FinanceKit account skipped — currency not modelled: \(input.currencyCode, privacy: .public)"
                    )
                }
            }
            return snapshots
        } catch let error as FinanceError {
            throw Self.providerError(for: error)
        } catch {
            Self.logger.error(
                "FinanceKit account fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw FinancialDataProviderError.refreshFailed
        }
    }

    func fetchTransactionSnapshots(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [FinancialTransactionSnapshot] {
        try await ensureAuthorized()

        guard let accountUUID = UUID(uuidString: accountID) else {
            throw FinancialDataProviderError.mappingFailed(field: "accountID")
        }

        do {
            let predicate = #Predicate<FinanceKit.Transaction> { transaction in
                transaction.accountID == accountUUID
                    && transaction.transactionDate >= startDate
                    && transaction.transactionDate <= endDate
            }
            let query = TransactionQuery(predicate: predicate)
            let transactions = try await FinanceStore.shared.transactions(query: query)
            var snapshots: [FinancialTransactionSnapshot] = []
            snapshots.reserveCapacity(transactions.count)
            for transaction in transactions {
                // Skip rejected / memo rows — they are not settled
                // charges and would double-book against the real
                // booked transaction that follows. Pending /
                // authorized rows are allowed through: the
                // reconciler's dedupe layer collapses them when the
                // booked version arrives.
                if transaction.status == .rejected || transaction.status == .memo {
                    continue
                }
                let input = Self.transactionInput(from: transaction)
                if let snapshot = FinanceKitSnapshotMapper.mapTransaction(input) {
                    snapshots.append(snapshot)
                }
            }
            return snapshots
        } catch let error as FinanceError {
            throw Self.providerError(for: error)
        } catch {
            Self.logger.error(
                "FinanceKit transaction fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw FinancialDataProviderError.refreshFailed
        }
    }

    // MARK: - Background update seam

    /// Official path for background delivery (iOS 26+) is to call
    /// `FinanceStore.shared.enableBackgroundDelivery(for:frequency:)`
    /// from a `BackgroundDeliveryExtension` app extension. NomadFi
    /// does not ship that extension in this slice — wiring it
    /// requires (1) a separate target, (2) additional entitlement
    /// work, and (3) a real device bakeout plan, all of which are
    /// tracked in `docs/research/FinanceKitFeasibility.md`.
    func scheduleBackgroundUpdates() async {
        // Intentionally empty. Once the background-delivery
        // extension ships, this wraps a call to
        // `FinanceStore.shared.enableBackgroundDelivery(
        //     for: [.accounts, .accountBalances, .transactions],
        //     frequency: .daily
        // )`. Keeping the seam avoids restructuring the coordinator
        // when the extension lands.
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
        case .notDetermined:
            throw FinancialDataProviderError.providerUnavailable(.entitlementNotProvisioned)
        case .unavailable:
            throw FinancialDataProviderError.providerUnavailable(.entitlementNotProvisioned)
        }
    }

    // MARK: - Static mapping (pure + testable)

    /// Typed projection from FinanceKit's enum to the provider-neutral
    /// authorization enum. Pure static so tests can assert against
    /// every branch without a device.
    static func map(_ status: FinanceKit.AuthorizationStatus) -> FinancialDataAuthorizationStatus {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .unavailable
        }
    }

    /// Maps a `FinanceError` onto the provider-neutral authorization
    /// enum. `.dataRestricted` covers both "entitlement missing" and
    /// "restricted by system policy" — NomadFi surfaces the calmer
    /// `.unavailable` in that case because the next step for the
    /// user is provisioning / system-level, not a consent prompt.
    static func authorizationStatus(for error: FinanceError) -> FinancialDataAuthorizationStatus {
        switch error {
        case .dataRestricted: .unavailable
        default: .unavailable
        }
    }

    /// Maps a `FinanceError` onto the provider-neutral error enum
    /// used by the coordinator and reconciler.
    static func providerError(for error: FinanceError) -> FinancialDataProviderError {
        switch error {
        case .dataRestricted:
            return .providerUnavailable(.entitlementNotProvisioned)
        default:
            return .refreshFailed
        }
    }

    /// Extracts primitive inputs from a FinanceKit account + its
    /// balances so the pure mapper can do the currency / type /
    /// sign work. Kept in the adapter because it touches framework
    /// types directly.
    static func accountInput(
        from account: FinanceKit.Account,
        balances: [FinanceKit.AccountBalance]
    ) -> FinanceKitSnapshotMapper.AccountInput {
        let kind: FinanceKitSnapshotMapper.AccountKind
        let creditLimit: Decimal?
        switch account {
        case .liability(let liability):
            kind = .liability
            creditLimit = liability.creditInformation.creditLimit?.amount
        case .asset:
            kind = .asset
            creditLimit = nil
        @unknown default:
            kind = .asset
            creditLimit = nil
        }
        let newest = balances.max { lhs, rhs in
            newestAsOfDate(lhs) < newestAsOfDate(rhs)
        }
        let bookedAmount = newest?.booked?.amount.amount
        let availableAmount = newest?.available?.amount.amount
        let asOfDate = newest.map(newestAsOfDate)

        // For a liability (credit card), booked = current owed
        // balance, available = remaining credit. For an asset
        // (deposit / wallet / savings), booked is the deposit
        // balance. Keep the statement-balance slot nil for now —
        // FinanceKit does not expose a separate statement balance
        // in the public API on this SDK.
        let current: Decimal? = bookedAmount ?? availableAmount
        return FinanceKitSnapshotMapper.AccountInput(
            id: account.id,
            displayName: account.displayName,
            institutionName: account.institutionName,
            currencyCode: account.currencyCode,
            kind: kind,
            creditLimit: creditLimit,
            refreshedAt: asOfDate,
            currentBalance: current,
            availableBalance: availableAmount,
            statementBalance: nil
        )
    }

    /// Extracts primitive inputs from a FinanceKit transaction.
    static func transactionInput(
        from transaction: FinanceKit.Transaction
    ) -> FinanceKitSnapshotMapper.TransactionInput {
        let indicator: FinanceKitSnapshotMapper.TransactionIndicator
        switch transaction.creditDebitIndicator {
        case .credit: indicator = .credit
        case .debit: indicator = .debit
        @unknown default: indicator = .debit
        }
        return FinanceKitSnapshotMapper.TransactionInput(
            id: transaction.id,
            accountID: transaction.accountID,
            amount: transaction.transactionAmount.amount,
            currencyCode: transaction.transactionAmount.currencyCode,
            indicator: indicator,
            merchantName: transaction.merchantName,
            description: transaction.transactionDescription,
            originalDescription: transaction.originalTransactionDescription,
            transactionDate: transaction.transactionDate,
            postedDate: transaction.postedDate,
            typeRawValue: transaction.transactionType.rawValue,
            statusRawValue: transaction.status.rawValue,
            merchantCategoryCodeRawValue: transaction.merchantCategoryCode?.rawValue
        )
    }

    private static func newestAsOfDate(_ balance: FinanceKit.AccountBalance) -> Date {
        switch balance.currentBalance {
        case .available(let b): return b.asOfDate
        case .booked(let b): return b.asOfDate
        case .availableAndBooked(_, let booked): return booked.asOfDate
        @unknown default: return .distantPast
        }
    }
}
