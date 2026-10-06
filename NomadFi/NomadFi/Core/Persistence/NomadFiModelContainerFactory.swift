// NomadFiModelContainerFactory.swift
// NomadFi
//
// Single chokepoint that constructs the production
// `ModelContainer` against `NomadFiSchemaV1` and
// `NomadFiMigrationPlan`. Centralising the construction means
// every entry point (the SwiftUI app, App Intents, widgets, the
// test factory) sees the same schema + the same migration plan.
//
// The construction explicitly wraps any thrown error so a
// migration failure surfaces as a deliberate fatal at launch
// rather than silently resetting the on-disk store. That trade-
// off — crash loudly instead of wipe quietly — is the whole
// reason the factory exists.

import Foundation
import OSLog
import SwiftData

/// Pure namespace that builds the production `ModelContainer`.
enum NomadFiModelContainerFactory {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "ModelContainer"
    )

    /// Production `ModelContainer` for the SwiftUI app. Always
    /// uses the explicit `NomadFiMigrationPlan` so future schema
    /// changes have to declare their migration intent.
    static func makeProduction() -> ModelContainer {
        do {
            let schema = Schema(versionedSchema: NomadFiSchemaV3.self)
            return try ModelContainer(
                for: schema,
                migrationPlan: NomadFiMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
            )
        } catch {
            // We intentionally crash here rather than fall back to
            // an in-memory store. A silent fallback would re-create
            // the exact failure mode this factory exists to prevent:
            // the user opening the app to find their data gone.
            // A loud crash forces a real fix (write a migration
            // stage, recover the store, or roll back the model
            // change) before shipping.
            logger.fault(
                "Failed to construct production ModelContainer: \(error.localizedDescription, privacy: .public)"
            )
            preconditionFailure("Failed to construct ModelContainer: \(error)")
        }
    }
}
