// NomadFiAppContainerHoistingTests.swift
// NomadFi
//
// Pins the rule that the production `ModelContainer` is constructed
// **once** at App-init time and held as a stored property on the
// `NomadFiApp` struct — never inlined inside the Scene body
// expression.
//
// Why this matters (incident learning):
//   `.modelContainer(NomadFiModelContainerFactory.makeProduction())`
//   inside the Scene body re-evaluates the factory on every Scene
//   body recomputation. Every `@State`, `@AppStorage`, or
//   `scenePhase` change on the App struct triggers that path, which
//   silently swaps in a fresh `ModelContainer` and tears down the
//   previous one. Any view that had already captured
//   `@Environment(\.modelContext)` ends up holding a destroyed
//   context, and the next SwiftData fetch traps with the runtime
//   assertion `"This model instance was destroyed by calling
//   ModelContext.reset and is no longer usable."` (the same trap
//   the runtime fires for individual destroyed model instances).
//
// SwiftUI's runtime can't be invoked from a unit test, so the
// guardrail is a source-level lint: read `NomadFiApp.swift` at test
// time and assert that:
//
//   1. The Scene body modifier passes a stored property
//      (`.modelContainer(modelContainer)`), not an inline factory
//      call (`.modelContainer(NomadFiModelContainerFactory…)`).
//   2. A stored `modelContainer` property exists on the App struct.
//   3. The `init()` body assigns to that stored property exactly
//      once via the factory.
//
// The iOS Simulator sandbox blocks reading source files outside the
// app bundle when tests run there; the assertions degrade to a
// soft-skip in that environment so CI runs that *can* read the
// source still enforce the rule.

import Foundation
import Testing

@testable import NomadFi

struct NomadFiAppContainerHoistingTests {

    @Test("NomadFiApp.swift passes a stored `modelContainer` to `.modelContainer(_)`, never the factory inline — inline calls re-create the container on every Scene body recomputation")
    func sceneBodyUsesStoredContainer() throws {
        guard let source = Self.appSourceIfReadable() else {
            // Sandboxed simulator run — guardrail still has value in
            // CI environments that can read the file. See file header.
            return
        }

        #expect(
            source.contains(".modelContainer(modelContainer)"),
            """
            NomadFiApp.swift must call `.modelContainer(modelContainer)` \
            with the app-owned stored property — never \
            `.modelContainer(NomadFiModelContainerFactory.makeProduction())` \
            inline. Inlining the factory call rebuilds the container on \
            every Scene body recomputation and destroys every \
            `ModelContext` the running app had captured. See the file \
            header in `NomadFiAppContainerHoistingTests.swift`.
            """
        )

        #expect(
            !source.contains(".modelContainer(NomadFiModelContainerFactory.makeProduction())"),
            """
            NomadFiApp.swift contains an inline \
            `.modelContainer(NomadFiModelContainerFactory.makeProduction())` \
            call. Hoist the container into a stored `let modelContainer` \
            property and pass it to `.modelContainer(_)` instead.
            """
        )
    }

    @Test("NomadFiApp.swift declares a single stored `modelContainer` property and assigns it once from the factory inside `init`")
    func appOwnsContainerAsStoredProperty() throws {
        guard let source = Self.appSourceIfReadable() else { return }

        #expect(
            source.contains("let modelContainer: ModelContainer"),
            """
            NomadFiApp must hold the SwiftData container as a stored \
            `let modelContainer: ModelContainer` property. Without a \
            stored property, the Scene body modifier evaluates the \
            factory on every recomputation.
            """
        )

        let assignmentOccurrences = source
            .components(separatedBy: "modelContainer = NomadFiModelContainerFactory.makeProduction()")
            .count - 1
        #expect(
            assignmentOccurrences == 1,
            """
            NomadFiApp.init must assign the stored `modelContainer` \
            exactly once via `NomadFiModelContainerFactory.makeProduction()`. \
            Found \(assignmentOccurrences) occurrence(s). More than one \
            assignment, or zero, would either re-create the container at \
            runtime or leave the stored property uninitialized.
            """
        )
    }

    // MARK: - Helpers

    /// Loads `NomadFiApp.swift` from disk relative to this test
    /// file's location. Returns `nil` when the sandbox blocks file
    /// reads (typical for iOS Simulator unit-test runs) so callers
    /// can degrade to a soft-skip rather than fail spuriously.
    private static func appSourceIfReadable() -> String? {
        let candidates = candidateAppSourcePaths()
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        return nil
    }

    private static func candidateAppSourcePaths() -> [URL] {
        let fileURL = URL(fileURLWithPath: #filePath)
        let testsDir = fileURL.deletingLastPathComponent()
        let projectRoots: [URL] = [
            testsDir.deletingLastPathComponent(),
            testsDir.deletingLastPathComponent().deletingLastPathComponent(),
        ]
        let relativePath = "NomadFi/App/NomadFiApp.swift"
        return projectRoots.map { $0.appendingPathComponent(relativePath) }
    }
}
