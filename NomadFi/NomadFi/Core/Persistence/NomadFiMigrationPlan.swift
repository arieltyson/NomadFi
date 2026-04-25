// NomadFiMigrationPlan.swift
// NomadFi
//
// Explicit migration plan for NomadFi's SwiftData store. Today
// only `NomadFiSchemaV1` exists — there is no migration stage
// because there is no predecessor — but the plan is wired in
// from day one so the very next schema change has to declare its
// intent rather than rely on SwiftData's heuristic migration.
//
// How to add a new model in the future:
//
//   1. Define `NomadFiSchemaV2: VersionedSchema` in a new file,
//      with `models` containing the V1 list **plus** the new
//      `@Model` type.
//   2. Bump `versionIdentifier` to `Schema.Version(2, 0, 0)`.
//   3. Append `NomadFiSchemaV2.self` to ``schemas``.
//   4. Append a `MigrationStage` between V1 and V2 — usually
//      `MigrationStage.lightweight(fromVersion:toVersion:)` is
//      enough when the new model has all-defaulted / optional
//      properties (see CloudKit-safe rules in `docs/ARIEL.md`).
//      For destructive or rename migrations use
//      `MigrationStage.custom(...)` and write the data-shaping
//      closure explicitly.
//   5. Update `SchemaSnapshotTests` so the snapshot still passes.
//
// Tests in `SchemaSnapshotTests` assert that the plan, the
// schema, and the production container agree on the same model
// list. A drift fails CI rather than data.

import Foundation
import SwiftData

/// Single migration plan for NomadFi's SwiftData store.
enum NomadFiMigrationPlan: SchemaMigrationPlan {

    /// Ordered list of schemas the plan knows about. V1 today;
    /// future versions append here.
    static var schemas: [any VersionedSchema.Type] {
        [NomadFiSchemaV1.self]
    }

    /// Ordered migration stages. Empty today because V1 has no
    /// predecessor; each future version adds its stage here.
    static var stages: [MigrationStage] {
        []
    }
}
