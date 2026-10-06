// SchemaSnapshotTests.swift
// NomadFi
//
// Hard guardrail against the failure mode that wiped the user's
// accounts: a `@Model` was added to the production container
// without a matching schema version, SwiftData reconciled by
// resetting the local store, and on the next launch the app
// opened with empty data.
//
// These tests pin three things so the next change can't repeat
// that pattern silently:
//
//   1. `NomadFiSchemaV1.models` matches an explicit, frozen
//      snapshot. Adding or removing a `@Model` here without
//      updating the snapshot fails CI.
//   2. `NomadFiMigrationPlan.schemas` references V1 (and only
//      V1) today. When V2 lands, the snapshot has to be bumped
//      *and* the plan has to gain a `MigrationStage`.
//   3. The test container factory and the production container
//      use the exact same model list — they cannot drift apart.
//
// If you intentionally change the schema:
//   • Define `NomadFiSchemaV2` in `Core/Persistence/`.
//   • Append it to `NomadFiMigrationPlan.schemas`.
//   • Append a `MigrationStage` to `NomadFiMigrationPlan.stages`
//     (lightweight is enough when every new property is optional
//     or defaulted; otherwise write a custom stage).
//   • Update the snapshot constant below.
//
// Do not "just update the snapshot" without the migration plan.
// That's the whole reason this test exists.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

struct SchemaSnapshotTests {

    /// Frozen snapshot of every `@Model` type in
    /// `NomadFiSchemaV1.models`, identified by their fully-
    /// qualified type names. Sorted so the assertion produces a
    /// stable diff. Edit only when you also bump the schema and
    /// add a migration stage.
    private static let v1Snapshot: [String] = [
        "Account",
        "Budget",
        "Currency",
        "DecisionDraftRecord",
        "DecisionReviewMarker",
        "ExchangeRate",
        "InvestingEducationProgressRecord",
        "JurisdictionProfile",
        "PurchaseDecisionRecord",
        "ScenarioDecisionRecord",
        "Subscription",
        "TaxDocument",
        "TaxEducationProgressRecord",
        "Transaction",
    ]

    // MARK: - Schema snapshot

    @Test("NomadFiSchemaV1.models matches the frozen V1 snapshot — adding or removing a @Model without bumping the schema fails this test")
    func v1ModelListMatchesSnapshot() {
        let actual = NomadFiSchemaV1.models
            .map { String(describing: $0) }
            .sorted()
        #expect(
            actual == Self.v1Snapshot,
            """
            NomadFiSchemaV1.models has drifted from the frozen \
            V1 snapshot. Do not just edit the snapshot — define \
            NomadFiSchemaV2, append it to NomadFiMigrationPlan, \
            and write the appropriate MigrationStage first. See \
            the file header in `SchemaSnapshotTests.swift`.

            Expected: \(Self.v1Snapshot)
            Actual:   \(actual)
            """
        )
    }

    @Test("NomadFiSchemaV1.versionIdentifier is 1.0.0 — bump only when introducing NomadFiSchemaV2")
    func v1VersionIdentifierIsOneZeroZero() {
        let version = NomadFiSchemaV1.versionIdentifier
        #expect(version == Schema.Version(1, 0, 0))
    }

    // MARK: - Migration plan

    @Test("Migration plan preserves V1 and introduces the hosted-state schema")
    func migrationPlanReferencesV1AndV2() {
        let names = NomadFiMigrationPlan.schemas
            .map { String(describing: $0) }
        #expect(names == ["NomadFiSchemaV1", "NomadFiSchemaV2", "NomadFiSchemaV3"])
    }

    @Test("Hosted-state storage has an explicit migration")
    func migrationPlanHasOneStage() {
        #expect(NomadFiMigrationPlan.stages.count == 2)
    }

    // MARK: - Production / test parity

    @Test("Test container factory and production schema reference the same model list — they cannot drift")
    func testFactoryAndProductionAgree() {
        let testNames = SwiftDataTestContainerFactory.fullAppSchema
            .map { String(describing: $0) }
            .sorted()
        let productionNames = NomadFiSchemaV3.models
            .map { String(describing: $0) }
            .sorted()
        #expect(testNames == productionNames)
    }

    @Test("Production container constructs successfully with the explicit migration plan")
    @MainActor
    func productionContainerConstructs() throws {
        // Smoke check: a fresh in-memory container with the
        // versioned schema + plan must build cleanly. If a future
        // model addition makes the plan inconsistent, this fails
        // in CI rather than on a user device.
        let container = try SwiftDataTestContainerFactory
            .makeFullSchemaContainer()
        #expect(container.schema.entities.count == NomadFiSchemaV3.models.count)
    }
}
