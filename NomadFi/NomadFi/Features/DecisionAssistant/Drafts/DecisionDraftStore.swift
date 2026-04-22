// DecisionDraftStore.swift
// NomadFi
//
// Pure, testable lifecycle helpers for ``DecisionDraftRecord``. Keeps
// archive / restore / delete logic out of the views so the UI layer
// only needs to dispatch user intent; the mutation and persistence
// stay in one place.
//
// Everything here is a static function on an `enum` namespace. No
// shared state, no dependency injection, no analytics — every call
// is a deterministic mutation of the record plus an explicit
// `context.save()` so the `@Query` observers on the Decision
// Assistant re-evaluate immediately.

import Foundation
import OSLog
import SwiftData

/// Lifecycle namespace for captured decision drafts.
///
/// Archive and restore are reversible and intentionally silent (no
/// confirmation dialog) per HIG alert guidance. Delete is
/// irreversible and *must* be confirmed by the caller before this
/// store removes the record.
enum DecisionDraftStore {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DecisionDraftStore"
    )

    // MARK: - Insert

    /// Inserts a fresh ``DecisionDraftRecord`` from already-supplied
    /// strings. Trims every text field, enforces that the scenario
    /// body is non-empty after trimming, stamps `createdAt` ==
    /// `updatedAt`, and persists the new record with status
    /// ``DecisionDraftStatus/needsEngine``.
    ///
    /// Called by both the in-app capture path (`DecisionDraftFormViewModel`,
    /// indirectly) and the Siri / Shortcuts intake path
    /// (`CaptureDecisionDraftIntent`) so voice and typed captures can
    /// never drift apart on validation or storage rules.
    ///
    /// - Returns: The inserted record, or `nil` when the scenario text
    ///   is empty / whitespace-only.
    @MainActor
    @discardableResult
    static func insertDraft(
        scenarioText: String,
        title: String = "",
        kind: DecisionDraftKind = .purchase,
        merchantName: String = "",
        locationText: String = "",
        amount: Double? = nil,
        currencyCode: CurrencyCode = .usd,
        timingText: String = "",
        notes: String = "",
        in modelContext: ModelContext,
        now: Date = .now
    ) -> DecisionDraftRecord? {
        let trimmedScenario = scenarioText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedScenario.isEmpty else {
            logger.debug("insertDraft refused — scenario text is empty after trimming")
            return nil
        }

        let record = DecisionDraftRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            scenarioText: trimmedScenario,
            kind: kind,
            merchantName: merchantName.trimmingCharacters(in: .whitespacesAndNewlines),
            locationText: locationText.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currencyCode: currencyCode,
            timingText: timingText.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .needsEngine,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(record)
        persist(modelContext, action: "insert")
        return record
    }

    // MARK: - Archive / restore

    /// Marks the draft as ``DecisionDraftStatus/archived`` and stamps
    /// `updatedAt`. Preserves `createdAt` and every user-entered
    /// field. No-op when the draft is already archived.
    @MainActor
    static func archive(
        _ draft: DecisionDraftRecord,
        in modelContext: ModelContext,
        now: Date = .now
    ) {
        guard draft.status != .archived else { return }
        draft.statusRawValue = DecisionDraftStatus.archived.rawValue
        draft.updatedAt = now
        persist(modelContext, action: "archive")
    }

    /// Restores an archived draft back to
    /// ``DecisionDraftStatus/needsEngine`` and stamps `updatedAt`.
    /// No-op when the draft is already active.
    @MainActor
    static func restore(
        _ draft: DecisionDraftRecord,
        in modelContext: ModelContext,
        now: Date = .now
    ) {
        guard draft.status != .needsEngine else { return }
        draft.statusRawValue = DecisionDraftStatus.needsEngine.rawValue
        draft.updatedAt = now
        persist(modelContext, action: "restore")
    }

    // MARK: - Delete

    /// Permanently deletes a single draft from the local store. The
    /// caller is responsible for confirming the user's intent before
    /// invoking this — the store itself never prompts.
    @MainActor
    static func delete(
        _ draft: DecisionDraftRecord,
        in modelContext: ModelContext
    ) {
        modelContext.delete(draft)
        persist(modelContext, action: "delete")
    }

    // MARK: - Private

    @MainActor
    private static func persist(
        _ modelContext: ModelContext,
        action: String
    ) {
        do {
            try modelContext.save()
        } catch {
            logger.error(
                "Failed to \(action, privacy: .public) draft: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
