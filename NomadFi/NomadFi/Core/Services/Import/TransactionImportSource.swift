// TransactionImportSource.swift
// NomadFi
//
// Identifier for how a `Transaction` arrived in NomadFi. Persisted as
// a String on `Transaction` so the schema stays CloudKit-safe (raw
// string, optional, defaulted). The engine never trusts these values
// as evidence of official institutional linkage — an "Amex-like CSV"
// is still a user-supplied file; only its header shape was matched.

import Foundation

/// Provenance label for transaction rows. New profiles can be added
/// without a schema migration because the raw value is just a
/// String column.
enum TransactionImportSource: String, Codable, Sendable, CaseIterable, Hashable {

    /// User typed the row through `AddTransactionView` — the shipping
    /// default before this phase.
    case manualEntry = "manual_entry"

    /// User provided a CSV file whose header shape didn't match any
    /// named profile. Ingested through the generic fallback profile.
    case csvGeneric = "csv_generic"

    /// CSV whose header aliases matched a Chase-style export shape.
    /// No affiliation; no official integration is implied.
    case csvChaseLike = "csv_chase_like"

    /// CSV whose header aliases matched a CIBC-style export shape.
    case csvCIBCLike = "csv_cibc_like"

    /// CSV whose header aliases matched an American Express Canada
    /// -style export shape.
    case csvAmexCanadaLike = "csv_amex_canada_like"

    /// CSV whose header aliases matched a Wise-style export shape.
    case csvWiseLike = "csv_wise_like"

    // MARK: - Display

    var displayLabel: String {
        switch self {
        case .manualEntry: "Manual entry"
        case .csvGeneric: "CSV import (generic)"
        case .csvChaseLike: "CSV import (Chase-like)"
        case .csvCIBCLike: "CSV import (CIBC-like)"
        case .csvAmexCanadaLike: "CSV import (Amex Canada-like)"
        case .csvWiseLike: "CSV import (Wise-like)"
        }
    }

    /// Whether this source came from a CSV file. Used by the UI to
    /// decide which rows carry an import timestamp / fingerprint.
    var isCSVImport: Bool {
        switch self {
        case .manualEntry: false
        case .csvGeneric, .csvChaseLike, .csvCIBCLike, .csvAmexCanadaLike, .csvWiseLike: true
        }
    }
}
