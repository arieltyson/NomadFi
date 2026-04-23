// ManualFinancialDataProvider.swift
// NomadFi
//
// Represents the user-typed source of truth that already lives in
// SwiftData on ``Account`` / ``Transaction`` rows. This provider never
// reaches outside the app — it exists so the coordinator can treat
// manual entry as a first-class, always-available source and so UI can
// honestly label the provenance of user-entered rows.

import Foundation

/// The user-typed data source. Always available, always authorized —
/// the user is already in the app. Returns no snapshots of its own
/// because the SwiftData store is already the authoritative truth;
/// the coordinator never needs to "sync" manual data.
struct ManualFinancialDataProvider: FinancialDataProvider {

    let kind: FinancialDataProviderKind = .manual

    func availability() async -> FinancialDataProviderAvailability {
        .available
    }

    func authorizationStatus() async -> FinancialDataAuthorizationStatus {
        .authorized
    }

    func requestAuthorization() async throws -> FinancialDataAuthorizationStatus {
        .authorized
    }

    func connections() async -> [FinancialDataConnection] {
        [
            FinancialDataConnection(
                id: "manual",
                providerKind: .manual,
                displayName: "Manual entry",
                status: .connected
            )
        ]
    }

    func fetchAccountSnapshots() async throws -> [FinancialAccountSnapshot] {
        []
    }

    func fetchTransactionSnapshots(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [FinancialTransactionSnapshot] {
        []
    }
}
