// TransactionImportViewModel.swift
// NomadFi
//
// Observable backing state for the CSV import flow. Keeps the file
// picker result, the parsed preview, and the selected target
// account together so the SwiftUI view can stay a thin render.
//
// The view model only calls pure `TransactionImportService` entry
// points — no SwiftData access except at commit time, and even then
// via the service's `commit(preview:into:)` helper.

import Foundation
import Observation
import OSLog
import SwiftData

/// States the import flow can occupy.
enum TransactionImportPhase: Sendable, Equatable {
    case selectingFile
    case parsing
    case preview(TransactionImportPreviewSnapshot)
    case committed(TransactionImportCommitResult)
    case error(String)
}

/// Sendable snapshot of a `TransactionImportPreview`. The underlying
/// `Transaction` value type is already Sendable, but wrapping keeps
/// the phase enum comparable without dragging the preview's
/// profile metadata into `Equatable`.
struct TransactionImportPreviewSnapshot: Sendable, Equatable {
    let sourceDisplayName: String
    let counts: TransactionImportCounts
    let rows: [TransactionImportPreviewRow]
}

/// Observable view model for the transaction import flow.
@MainActor
@Observable
final class TransactionImportViewModel {

    // MARK: - Dependencies

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "TransactionImportVM"
    )

    /// Clock seam used to stamp `Transaction.importedAt`. Tests pin
    /// the value.
    private let clock: @Sendable () -> Date

    // MARK: - Inputs

    /// Target account for the import. Set from the view via the
    /// account picker before the user chooses a file.
    var selectedAccount: Account?

    /// Home currency to tag on each imported row. Defaults to the
    /// selected account's currency — the view can override.
    var homeCurrency: CurrencyCode = .usd

    // MARK: - State

    /// Current phase. `.selectingFile` until the user picks a file.
    private(set) var phase: TransactionImportPhase = .selectingFile

    /// Kept alive across `.preview` so `commit()` can rerun the same
    /// parse output the user confirmed. Never read by the view.
    private var pendingPreview: TransactionImportPreview?

    // MARK: - Init

    init(clock: @escaping @Sendable () -> Date = { .now }) {
        self.clock = clock
    }

    // MARK: - Intents

    /// Reads `fileURL` into memory, parses it against the detected
    /// profile, and transitions into `.preview` (or `.error`).
    func loadFile(
        at fileURL: URL,
        existingTransactions: [Transaction]
    ) {
        guard let account = selectedAccount else {
            phase = .error("Select an account before importing.")
            return
        }

        phase = .parsing

        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            Self.logger.error("Failed to read CSV file: \(error.localizedDescription, privacy: .public)")
            phase = .error("Couldn't read that file. Choose a text-based CSV file exported from your bank or card issuer.")
            return
        }

        guard let text = decode(data: data) else {
            phase = .error("The file's text encoding isn't supported. Re-export the CSV as UTF-8.")
            return
        }

        let preview = TransactionImportService.parse(
            csvText: text,
            profileOverride: nil,
            account: account,
            homeCurrency: homeCurrency,
            existingTransactions: existingTransactions,
            now: clock()
        )

        pendingPreview = preview
        phase = .preview(TransactionImportPreviewSnapshot(
            sourceDisplayName: preview.profile.displayName,
            counts: preview.counts,
            rows: preview.rows
        ))
    }

    /// Commits `.new` rows into the given `ModelContext`. Transitions
    /// into `.committed` on success.
    func commit(into modelContext: ModelContext) {
        guard let account = selectedAccount,
              let preview = pendingPreview
        else {
            phase = .error("Missing account or preview — pick a CSV file again.")
            return
        }

        let result = TransactionImportService.commit(
            preview: preview,
            into: modelContext,
            account: account,
            homeCurrency: homeCurrency,
            now: clock()
        )
        pendingPreview = nil
        phase = .committed(result)
    }

    /// Returns to the file-picker phase so the user can import
    /// another CSV without dismissing the sheet.
    func reset() {
        pendingPreview = nil
        phase = .selectingFile
    }

    // MARK: - Helpers

    /// Attempts UTF-8 first, then falls back to the most common
    /// Windows-1252 shape some Canadian bank exports still use.
    private func decode(data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let windows = String(data: data, encoding: .windowsCP1252) {
            return windows
        }
        return nil
    }
}
