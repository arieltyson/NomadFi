// ParsedImportedRow.swift
// NomadFi
//
// Per-row value types the import service emits. Kept pure so the
// preview UI renders directly from these without touching SwiftData
// until the user confirms.

import Foundation

/// A single CSV row after the profile has parsed it into typed
/// fields. Always immutable; the service produces a new value per
/// row rather than mutating in place.
struct ParsedImportedRow: Sendable, Equatable {

    /// 1-based line number of the row in the source file, used only
    /// to help the user diagnose a rejected row.
    let lineNumber: Int

    /// Original merchant name exactly as it appeared in the CSV,
    /// before normalisation.
    let rawMerchantName: String

    /// `MerchantNormalizer.normalize(rawMerchantName)` — persisted
    /// on `Transaction.normalizedMerchantName` for matching.
    let normalizedMerchantName: String

    /// Inferred default category. The user can edit before confirm.
    let inferredCategory: TransactionCategory

    /// Amount as it should be saved on `Transaction.originalAmount`
    /// (negative = debit).
    let amount: Double

    /// Currency from the CSV or the profile's default.
    let currencyCode: CurrencyCode

    /// Parsed posting/transaction date.
    let date: Date

    /// Optional issuer-provided ID. Drives the highest-confidence
    /// dedupe path when present.
    let externalTransactionID: String?

    /// Deterministic fingerprint — stable across runs for the same
    /// row shape. Used by dedupe when no external ID is available.
    let fingerprint: String
}

/// Every preview row the user sees before confirming the import.
/// Each variant carries enough information for the UI to label the
/// row and, for rejected rows, explain why.
enum TransactionImportPreviewRow: Sendable, Equatable, Identifiable {

    case new(ParsedImportedRow)
    case duplicate(ParsedImportedRow, reason: String)
    case skipped(lineNumber: Int, raw: String, error: TransactionImportError)

    var id: Int {
        switch self {
        case .new(let parsed): parsed.lineNumber
        case .duplicate(let parsed, _): parsed.lineNumber
        case .skipped(let lineNumber, _, _): lineNumber
        }
    }

    /// Count buckets the preview surfaces. A row is exactly one of
    /// these.
    enum Kind: Sendable, Equatable {
        case new
        case duplicate
        case skipped
    }

    var kind: Kind {
        switch self {
        case .new: .new
        case .duplicate: .duplicate
        case .skipped: .skipped
        }
    }
}

/// Counts displayed at the top of the preview sheet. Kept as its own
/// value type so tests can assert the shape the UI expects without
/// inspecting a `[TransactionImportPreviewRow]` directly.
struct TransactionImportCounts: Sendable, Equatable {

    let new: Int
    let duplicate: Int
    let skipped: Int

    var total: Int { new + duplicate + skipped }

    static let zero = TransactionImportCounts(new: 0, duplicate: 0, skipped: 0)
}

/// The full preview handed back to the UI.
struct TransactionImportPreview: Sendable {

    /// The profile used to parse the file.
    let profile: CSVImportProfile

    /// Every row the parser emitted, in file order. The UI can
    /// filter by `kind` to show per-bucket lists.
    let rows: [TransactionImportPreviewRow]

    /// Summary counts — matches `rows` bucketed by `kind`.
    let counts: TransactionImportCounts
}

/// Result of committing a preview. Keeps the UI honest about how
/// many rows were actually persisted and what was skipped.
struct TransactionImportCommitResult: Sendable, Equatable {

    /// How many `.new` rows became `Transaction` records.
    let inserted: Int

    /// How many rows were labelled duplicate at preview time and
    /// intentionally skipped at commit time.
    let skippedDuplicates: Int

    /// How many rows were `.skipped` at preview time.
    let skippedInvalid: Int

    static let zero = TransactionImportCommitResult(
        inserted: 0,
        skippedDuplicates: 0,
        skippedInvalid: 0
    )
}
