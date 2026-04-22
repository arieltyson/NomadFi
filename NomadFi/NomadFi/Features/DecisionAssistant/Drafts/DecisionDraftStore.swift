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
