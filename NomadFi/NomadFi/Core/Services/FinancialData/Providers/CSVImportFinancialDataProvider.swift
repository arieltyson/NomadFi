// CSVImportFinancialDataProvider.swift
// NomadFi
//
// Adapter that surfaces the existing deterministic CSV import pipeline
// (`Core/Services/Import/`) as a ``FinancialDataProvider``. CSV import
// is user-initiated: the user picks a file, the parser runs, and the
// resulting rows land in SwiftData via ``TransactionImportService``.
// There is no background "sync" — this provider's role in the
// coordinator is to represent the import seam honestly so UI can
// surface it alongside FinanceKit and a future aggregator without
// implying any of them provide the same coverage.

import Foundation

/// Treats CSV imports as a provider with a single implicit connection.
/// Never produces snapshots directly; the import pipeline already
/// writes to the store. Kept as a dedicated provider type so UI,
/// logging, and fallback logic can reason about imported data the
/// same way they reason about FinanceKit or a future aggregator.
struct CSVImportFinancialDataProvider: FinancialDataProvider {

    let kind: FinancialDataProviderKind = .csvImport

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
                id: "csv-import",
                providerKind: .csvImport,
                displayName: "CSV import",
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
