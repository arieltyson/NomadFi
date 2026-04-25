// ScenarioDecisionBriefViewModel.swift
// NomadFi
//
// Binds a persisted `ScenarioDecisionRecord` to the detail sheet,
// re-running the pure engine whenever the user edits an input.
// Persistence is handled by SwiftData's autosave; the view model only
// stamps `updatedAt` so the UI has a consistent signal for edits.
//
// Crash-safety note (incident learning):
//   Holding a long-lived strong reference to a SwiftData `@Model`
//   instance is unsafe — when SwiftData's runtime resets the
//   underlying context (e.g. as part of error recovery or a
//   cross-context refresh after an unrelated save), the held
//   reference is destroyed. Subsequent property access traps with
//   `"This model instance was destroyed by calling
//   ModelContext.reset and is no longer usable."`. The fix is to
//   re-resolve the record from the `ModelContext` on every access
//   via `ModelContext.registeredModel(for:)`, falling back to a
//   stable-ID re-fetch when the row is no longer registered (post-
//   reset). Apple's documented `PersistentIdentifier` round-trip is
//   the supported way to keep a stable handle to a SwiftData row.

import Foundation
import OSLog
import SwiftData

/// View model behind the Scenario 1 Amazon arrival-order decision brief.
@MainActor
@Observable
final class ScenarioDecisionBriefViewModel {

    // MARK: - Dependencies

    /// The immutable scenario facts. Defaulted to the Scenario 1 fixture.
    let facts: ScenarioFacts

    /// The curated source catalog shown in the "Sources" section.
    let citations: [ScenarioCitation]

    /// SwiftData context used to re-resolve `record` on every access.
    /// `nil` for previews and pure-value tests, where the held
    /// `detachedRecord` is the source of truth.
    private let modelContext: ModelContext?

    /// Stable identifier captured at init time when a `modelContext`
    /// was supplied. Used by `record` to re-resolve via
    /// `ModelContext.registeredModel(for:)` after a context reset.
    private let recordID: PersistentIdentifier?

    /// Fallback record used when no `modelContext` was supplied
    /// (previews, pure-value tests, fixtures).
    private let detachedRecord: ScenarioDecisionRecord

    // MARK: - Init

    /// Detached initializer for previews + pure-value tests. The
    /// held `record` is the source of truth; no re-resolution
    /// happens because nothing is destroying it from another path.
    convenience init(
        facts: ScenarioFacts = .scenario1,
        record: ScenarioDecisionRecord = ScenarioDecisionRecord(
            scenarioID: ScenarioDecisionRecord.scenario1ID
        ),
        citations: [ScenarioCitation] = ScenarioCitationCatalog.scenario1
    ) {
        self.init(
            facts: facts,
            modelContext: nil,
            record: record,
            citations: citations
        )
    }

    /// Production initializer. Captures the `ModelContext` so the
    /// view model can re-resolve `record` after a SwiftData context
    /// reset, instead of holding a strong reference that may be
    /// destroyed by an unrelated save on the same context.
    init(
        facts: ScenarioFacts = .scenario1,
        modelContext: ModelContext?,
        record: ScenarioDecisionRecord,
        citations: [ScenarioCitation] = ScenarioCitationCatalog.scenario1
    ) {
        self.facts = facts
        self.modelContext = modelContext
        // Only capture a `PersistentIdentifier` when we actually have
        // a context to round-trip through; otherwise `recordID` would
        // be useless for resolution.
        self.recordID = modelContext != nil ? record.persistentModelID : nil
        self.detachedRecord = record
        self.citations = citations
    }

    // MARK: - Record resolution

    /// The persisted record. When backed by a `ModelContext`, this
    /// re-resolves on every access — surviving the SwiftData
    /// "destroyed by ModelContext.reset" trap that fires when an
    /// unrelated save invalidates a held reference. When detached
    /// (previews / tests), returns the held instance directly.
    var record: ScenarioDecisionRecord {
        guard let modelContext, let recordID else {
            return detachedRecord
        }
        let registered: ScenarioDecisionRecord? = modelContext
            .registeredModel(for: recordID)
        if let registered { return registered }
        // Not registered — the context was reset or the row was
        // pruned. Re-fetch by stable scenario ID, which re-registers
        // a fresh, valid instance.
        return Self.fetchOrCreateScenario1Record(in: modelContext)
    }

    // MARK: - Derived

    /// Pure snapshot of the persisted record.
    var state: ScenarioDecisionState {
        ScenarioDecisionState(record: record)
    }

    /// The engine's current deterministic decision.
    var decision: ScenarioDecision {
        ScenarioDecisionEngine.decide(
            facts: facts,
            state: state,
            citations: citations
        )
    }

    // MARK: - Mutations

    /// Stamps `updatedAt` on the record. The caller is responsible for
    /// modifying the record's fields in-line with SwiftUI `@Bindable`
    /// bindings; this just keeps the freshness signal truthful.
    func markEdited(at date: Date = .now) {
        record.updatedAt = date
    }
}

// MARK: - Record bootstrap

extension ScenarioDecisionBriefViewModel {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "ScenarioDecisionBrief"
    )

    /// Fetches the Scenario 1 record, creating and inserting a new one
    /// if it does not yet exist. Runs on the main actor because
    /// `ModelContext` is main-actor-bound under the default SwiftData
    /// configuration.
    @MainActor
    static func fetchOrCreateScenario1Record(
        in modelContext: ModelContext
    ) -> ScenarioDecisionRecord {
        let scenarioID = ScenarioDecisionRecord.scenario1ID
        var descriptor = FetchDescriptor<ScenarioDecisionRecord>(
            predicate: #Predicate { $0.scenarioID == scenarioID }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let fresh = ScenarioDecisionRecord(scenarioID: scenarioID)
        modelContext.insert(fresh)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to insert scenario record: \(error.localizedDescription, privacy: .public)")
        }
        return fresh
    }
}
