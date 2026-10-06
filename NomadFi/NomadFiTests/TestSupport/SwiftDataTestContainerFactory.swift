// SwiftDataTestContainerFactory.swift
// NomadFi
//
// Canonical in-memory `ModelContainer` factory for SwiftData tests.
//
// Why this exists:
// `DataGovernancePolicy.deleteAllUserData` iterates `modelContext.delete(
// model: …)` across every `@Model` type the production app registers.
// If a test's in-memory container doesn't register one of those types,
// SwiftData aborts the test host with `SIGABRT` the moment the wipe
// reaches the unregistered class. When a new `@Model` is added to the
// app (e.g. `PurchaseDecisionRecord` in Phase 3), every wipe-related
// test container has to be updated or the suite crashes.
//
// Rather than duplicating the list in every test file, wipe-related
// tests route through this factory. Adding a future `@Model` becomes a
// one-file edit here, and the production `NomadFiApp.modelContainer`
// stays the single source of truth the factory mirrors.
//
// Non-wipe tests that only need a subset of types (e.g. an `Account`-
// only schedule test) can still build their own narrow containers —
// they don't hit the delete path, so they can stay minimal.

import Foundation
import SwiftData

@testable import NomadFi

/// Produces fresh in-memory SwiftData containers and contexts that
/// register every `@Model` type the production app ships.
///
/// Keep the ``fullAppSchema`` list in lock-step with the
/// `modelContainer(for:)` call in `NomadFiApp` — if the app gains a
/// model, add it here too. The test suite treats this as the single
/// source of truth for wipe-safe test containers.
enum SwiftDataTestContainerFactory {

    /// Every `@Model` type the production `NomadFiApp.modelContainer`
    /// registers today. Sourced from `NomadFiSchemaV1.models` so a
    /// schema bump in production cannot drift from the test
    /// container — both reference the same versioned schema.
    static var fullAppSchema: [any PersistentModel.Type] {
        NomadFiSchemaV2.models
    }

    /// Builds an in-memory `ModelContainer` with the full app schema
    /// **and** the production `NomadFiMigrationPlan`. Tests exercise
    /// the same migration path the app does so a broken plan fails
    /// in CI rather than on a user device.
    static func makeFullSchemaContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: NomadFiSchemaV2.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: NomadFiMigrationPlan.self,
            configurations: configuration
        )
    }

    /// Builds a `ModelContext` backed by a fresh full-schema
    /// container. Intended entry point for wipe-related tests — any
    /// test that calls `DataGovernancePolicy.deleteAllUserData`
    /// should use this so a future `@Model` addition never re-creates
    /// the schema-mismatch `SIGABRT`.
    @MainActor
    static func makeFullSchemaContext() throws -> ModelContext {
        ModelContext(try makeFullSchemaContainer())
    }
}
