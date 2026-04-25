// AppRoutingDefaultsTests.swift
// NomadFi
//
// Pins the App Group shared-defaults chokepoint plus the
// source-level guarantee that the entire app-routing seam
// (intents + SwiftUI consumers + value-typed store) uses the
// shared suite — never `UserDefaults.standard`. Writing through
// `.standard` is the original bug this slice exists to fix:
// `.standard` is the *current process's* defaults, so a widget-
// extension write is invisible to the main-app consumer.
//
// Two layers of pins:
//
//   1. Runtime smoke — `AppRoutingDefaults.shared` resolves to a
//      live `UserDefaults` instance and round-trips a key/value.
//      The shared suite is reused from the snapshot channel, so
//      this also exercises the same identifier the rest of the
//      app/widget data plane depends on.
//
//   2. Source-level chokepoint — every routing intent and every
//      SwiftUI consumer in the routing seam must use either
//      `AppRoutingDefaults.shared` (main app) or a
//      `UserDefaults(suiteName: NomadFiWidgetSharedConstants.appGroupIdentifier)`
//      construction (widget mirror). A future contributor that
//      reaches for `UserDefaults.standard` in any of these files
//      fails the suite immediately rather than shipping a
//      cross-process regression.
//
// The simulator sandbox can block file reads outside the bundle;
// in that environment the source-level cases degrade to a
// soft-skip (same pattern the other design-system guardrails
// use) so the suite still runs cleanly there.

import Foundation
import Testing

@testable import NomadFi

struct AppRoutingDefaultsTests {

    // MARK: - Runtime smoke

    @Test("AppRoutingDefaults.appGroupIdentifier matches the snapshot channel's identifier — single source of truth across the app/widget data plane")
    func appGroupIdentifierMatchesSnapshotChannel() {
        #expect(
            AppRoutingDefaults.appGroupIdentifier == NomadFiWidgetSharedConstants.appGroupIdentifier
        )
    }

    @Test("AppRoutingDefaults.shared resolves to a live UserDefaults that round-trips a key/value — App Groups capability is wired correctly")
    func sharedSuiteRoundTripsValues() {
        let testKey = "nomadfi.tests.routingDefaults.\(UUID().uuidString)"
        let testValue = "round-trip"
        AppRoutingDefaults.shared.set(testValue, forKey: testKey)
        defer { AppRoutingDefaults.shared.removeObject(forKey: testKey) }

        #expect(AppRoutingDefaults.shared.string(forKey: testKey) == testValue)
    }

    // MARK: - Source-level chokepoint guards

    @Test("Every main-app routing intent writes through AppRoutingDefaults.shared, never UserDefaults.standard")
    func mainAppRoutingIntentsUseSharedDefaults() throws {
        let mainAppIntents = [
            "NomadFi/Features/Intents/OpenDecisionAssistantIntent.swift",
            "NomadFi/Features/Intents/OpenAIIntakeIntent.swift",
            "NomadFi/Features/Intents/StartAIIntakeIntent.swift",
            "NomadFi/Features/Intents/StartDraftCaptureIntent.swift",
            "NomadFi/Features/Intents/ContinueAmazonArrivalDecisionIntent.swift",
        ]
        for path in mainAppIntents {
            guard let source = Self.sourceIfReadable(relativePath: path) else { continue }

            #expect(
                source.contains("AppRoutingDefaults.shared"),
                """
                \(path) must route its tab-selection / pending-request \
                writes through `AppRoutingDefaults.shared`. Writing \
                through `UserDefaults.standard` would re-introduce \
                the per-process bug — the widget's standard defaults \
                are not the main app's.
                """
            )
            #expect(
                !source.contains("UserDefaults.standard"),
                """
                \(path) must not reference `UserDefaults.standard`. \
                Use `AppRoutingDefaults.shared` for routing writes; \
                the App Group suite is the only channel the main-app \
                consumer reads.
                """
            )
        }
    }

    @Test("PendingAIIntakeRequestStore defaults its UserDefaults parameters to AppRoutingDefaults.shared")
    func storeDefaultsToSharedSuite() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/Intents/PendingAIIntakeRequestStore.swift"
        ) else { return }

        #expect(
            source.contains("UserDefaults = AppRoutingDefaults.shared"),
            """
            PendingAIIntakeRequestStore's read / consume / write / \
            clear functions must default their `UserDefaults` \
            parameter to `AppRoutingDefaults.shared`. A
             `.standard` default would silently ship cross-process \
            regressions any time a caller forgot to pass a suite.
            """
        )
        #expect(
            !source.contains("UserDefaults = .standard"),
            """
            PendingAIIntakeRequestStore must not default its \
            `UserDefaults` parameter to `.standard` — see file \
            header for the App Group rationale.
            """
        )
    }

    @Test("MainTabView's @AppStorage binds to the AppRoutingDefaults.shared store — without `store:` SwiftUI uses .standard, which would never observe a widget write")
    func mainTabViewBindsToSharedStore() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/App/MainTabView.swift"
        ) else { return }

        #expect(
            source.contains("@AppStorage(MainTabSelection.storageKey, store: AppRoutingDefaults.shared)"),
            """
            MainTabView must declare \
            `@AppStorage(MainTabSelection.storageKey, store: AppRoutingDefaults.shared)`. \
            Without the explicit store, SwiftUI uses \
            `UserDefaults.standard`, which never observes a write \
            from the widget extension's process.
            """
        )
    }

    @Test("DecisionAssistantView's pending-AI @AppStorage binds to the AppRoutingDefaults.shared store")
    func decisionAssistantViewBindsToSharedStore() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/DecisionAssistant/DecisionAssistantView.swift"
        ) else { return }

        #expect(
            source.contains("@AppStorage(PendingAIIntakeRequest.storageKey, store: AppRoutingDefaults.shared)"),
            """
            DecisionAssistantView's pending-AI-intake `@AppStorage` \
            must bind to the App Group shared suite via \
            `store: AppRoutingDefaults.shared`. Without it the \
            consumer reads from `.standard`, which never observes \
            a write from the widget extension's process.
            """
        )
    }

    // MARK: - Helpers

    /// Loads `relativePath` (under the app's source root) off disk.
    /// Returns `nil` when the sandbox blocks file reads (typical
    /// for iOS Simulator unit-test runs) so callers can degrade to
    /// a soft-skip rather than fail spuriously.
    private static func sourceIfReadable(relativePath: String) -> String? {
        let candidates = candidateSourcePaths(for: relativePath)
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        return nil
    }

    private static func candidateSourcePaths(for relativePath: String) -> [URL] {
        let fileURL = URL(fileURLWithPath: #filePath)
        let testsDir = fileURL.deletingLastPathComponent()
        let projectRoots: [URL] = [
            testsDir.deletingLastPathComponent(),
            testsDir.deletingLastPathComponent().deletingLastPathComponent(),
        ]
        return projectRoots.map { $0.appending(path: relativePath) }
    }
}
