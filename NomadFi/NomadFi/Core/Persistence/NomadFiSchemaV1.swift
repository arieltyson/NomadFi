// NomadFiSchemaV1.swift
// NomadFi
//
// Single source of truth for every `@Model` type the production
// SwiftData container ships today. Snapshotted as a
// `VersionedSchema` so future schema additions / removals go
// through `NomadFiMigrationPlan` rather than relying on
// SwiftData's heuristic auto-migration.
//
// Rationale (incident learning):
//   When a new `@Model` is added to the container without a
//   matching schema version, SwiftData must reconcile the on-disk
//   store against the new shape. If reconciliation fails, the
//   local store can be reset — silently emptying user data on the
//   next launch. Encoding the model list inside an explicit
//   versioned schema turns that into an intentional, reviewable
//   step: the contributor must add a new schema version and a
//   `MigrationStage` rather than just appending to a list.
//
// Editing rule:
//   • Never edit `NomadFiSchemaV1.models`.
//   • To add or remove a `@Model`, add a new
//     `NomadFiSchemaV2` (next file alongside this one) and append
//     a `MigrationStage` to `NomadFiMigrationPlan.stages`.
//   • The `SchemaSnapshotTests` suite pins the V1 model count and
//     identifiers so this rule cannot be bypassed silently.

import Foundation
import SwiftData

/// Initial production schema. Lists every `@Model` currently
/// shipped in `NomadFiApp`'s container, in the order the app has
/// historically registered them.
enum NomadFiSchemaV1: VersionedSchema {

    /// Declared schema version. Bumped only when a successor
    /// `NomadFiSchemaV2` is introduced alongside a matching
    /// migration stage.
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    /// Frozen list of `@Model` types in V1. Order matches the
    /// historical `modelContainer(for:)` array so existing on-disk
    /// stores recognise the shape on first launch under the
    /// versioned plan.
    static var models: [any PersistentModel.Type] {
        [
            Currency.self,
            JurisdictionProfile.self,
            Account.self,
            Transaction.self,
            ExchangeRate.self,
            TaxDocument.self,
            Subscription.self,
            Budget.self,
            ScenarioDecisionRecord.self,
            DecisionDraftRecord.self,
            PurchaseDecisionRecord.self,
            DecisionReviewMarker.self,
            TaxEducationProgressRecord.self,
            InvestingEducationProgressRecord.self,
        ]
    }
}
