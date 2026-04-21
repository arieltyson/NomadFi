// ScenarioDecisionBriefViewModel.swift
// NomadFi
//
// Binds a persisted `ScenarioDecisionRecord` to the detail sheet,
// re-running the pure engine whenever the user edits an input.
// Persistence is handled by SwiftData's autosave; the view model only
// stamps `updatedAt` so the UI has a consistent signal for edits.

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

    /// The persisted record backing the decision inputs. Mutations on
    /// this record auto-save through SwiftData.
    let record: ScenarioDecisionRecord

    // MARK: - Init

    init(
        facts: ScenarioFacts = .scenario1,
        record: ScenarioDecisionRecord = ScenarioDecisionRecord(
            scenarioID: ScenarioDecisionRecord.scenario1ID
        ),
        citations: [ScenarioCitation] = ScenarioCitationCatalog.scenario1
    ) {
        self.facts = facts
        self.record = record
        self.citations = citations
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
