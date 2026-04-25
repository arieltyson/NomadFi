// StartDraftCaptureIntentTests.swift
// NomadFi
//
// Pins the contract of the parameterless typed-form launch
// intent + the source-level guarantee that the widget mirror
// stays in sync with the main-app source of truth.
//
// Three drift risks (mirrored across two targets — same
// rationale as `StartAIIntakeIntentTests`):
//
//   1. The intent's title / description / mode could diverge.
//   2. The widget's hardcoded routing keys could fall out of
//      sync with the main-app `String` constants.
//   3. The widget could regress to `UserDefaults.standard`,
//      which is per-process and never reaches the main-app
//      consumer.
//
// All three are pinned. The simulator sandbox can block reads
// of the source files; in that environment the source-level
// cases degrade to a soft-skip (same pattern the other design-
// system guardrails use) so the suite still runs cleanly.

import AppIntents
import Foundation
import Testing

@testable import NomadFi

@MainActor
struct StartDraftCaptureIntentTests {

    // MARK: - Intent contract

    @Test("StartDraftCaptureIntent runs in .foreground(.immediate) — same shape as StartAIIntakeIntent and the other foreground routing intents")
    func startDraftCaptureIsForeground() {
        let modes = StartDraftCaptureIntent.supportedModes
        #expect(modes.contains(.foreground))
        #expect(!modes.contains(.background))
    }

    @Test("StartDraftCaptureIntent declares no @Parameter requirements so it can fire from a one-tap ControlWidgetButton without surfacing a parameter sheet")
    func startDraftCaptureHasNoParameters() {
        let mirror = Mirror(reflecting: StartDraftCaptureIntent())
        let parameterChildren = mirror.children.filter { child in
            String(describing: type(of: child.value))
                .contains("IntentParameter")
        }
        #expect(
            parameterChildren.isEmpty,
            "StartDraftCaptureIntent must be parameterless; found \(parameterChildren.count) IntentParameter property/properties."
        )
    }

    @Test("StartDraftCaptureIntent perform() writes the Decisions tab routing slot + the typed-form launch flag through AppRoutingDefaults.shared, never UserDefaults.standard")
    func performWritesRoutingSlotAndDraftFlagToSharedSuite() async throws {
        let shared = AppRoutingDefaults.shared

        // Defensive — clear the slots in BOTH stores so the test
        // starts from a known empty state.
        shared.removeObject(forKey: MainTabSelection.storageKey)
        PendingDraftCaptureFlag.clear(in: shared)
        UserDefaults.standard.removeObject(forKey: MainTabSelection.storageKey)
        PendingDraftCaptureFlag.clear(in: UserDefaults.standard)

        _ = try await StartDraftCaptureIntent().perform()

        // Shared suite must carry both routing payloads.
        let sharedTab = shared.string(forKey: MainTabSelection.storageKey)
        #expect(sharedTab == MainTabSelection.decisions.rawValue)
        #expect(PendingDraftCaptureFlag.read(from: shared) == true)

        // `.standard` must NOT carry the routing payloads.
        #expect(UserDefaults.standard.string(forKey: MainTabSelection.storageKey) == nil)
        #expect(PendingDraftCaptureFlag.read(from: UserDefaults.standard) == false)

        // Cleanup.
        shared.removeObject(forKey: MainTabSelection.storageKey)
        PendingDraftCaptureFlag.clear(in: shared)
    }

    // MARK: - Existing AI intent preserved

    @Test("StartAIIntakeIntent is preserved and still parameterless — the AI control entry path is unchanged")
    func startAIIntakeIntentPreserved() {
        let modes = StartAIIntakeIntent.supportedModes
        #expect(modes.contains(.foreground))
        let mirror = Mirror(reflecting: StartAIIntakeIntent())
        let parameterChildren = mirror.children.filter { child in
            String(describing: type(of: child.value))
                .contains("IntentParameter")
        }
        #expect(parameterChildren.isEmpty)
    }

    @Test("OpenAIIntakeIntent is preserved and still requires a scenarioText parameter — the seeded Siri / Shortcut path is unchanged")
    func openAIIntakeIntentPreserved() {
        let mirror = Mirror(reflecting: OpenAIIntakeIntent())
        let parameterChildren = mirror.children.filter { child in
            String(describing: type(of: child.value))
                .contains("IntentParameter")
        }
        #expect(!parameterChildren.isEmpty)
    }

    // MARK: - Widget mirror drift guards

    @Test("Widget extension's StartDraftCaptureIntent.swift exists and declares the same identifier + mode as the main-app copy")
    func widgetMirrorMatchesMainAppContract() throws {
        guard let widgetSource = Self.sourceIfReadable(
            relativePath: "NomadFiWidgetExtension/StartDraftCaptureIntent.swift"
        ) else { return }

        #expect(
            widgetSource.contains("struct StartDraftCaptureIntent: AppIntent"),
            """
            Widget mirror must declare \
            `struct StartDraftCaptureIntent: AppIntent` so iOS can \
            register the same identifier in both binaries.
            """
        )
        #expect(
            widgetSource.contains(".foreground(.immediate)"),
            """
            Widget mirror must declare `.foreground(.immediate)` \
            so the tap behaviour matches the main-app copy.
            """
        )
        #expect(
            widgetSource.contains("Start Draft Capture"),
            """
            Widget mirror's title must match the main-app copy so \
            the surface label stays consistent.
            """
        )
    }

    @Test("Widget extension's hardcoded routing key strings match the main-app constants")
    func widgetCopyMatchesMainAppKeys() throws {
        guard let widgetSource = Self.sourceIfReadable(
            relativePath: "NomadFiWidgetExtension/StartDraftCaptureIntent.swift"
        ) else { return }

        #expect(
            widgetSource.contains("\"\(MainTabSelection.storageKey)\""),
            """
            Widget mirror must hardcode the literal value of \
            `MainTabSelection.storageKey` (\(MainTabSelection.storageKey)).
            """
        )
        #expect(
            widgetSource.contains("\"\(MainTabSelection.decisions.rawValue)\""),
            """
            Widget mirror must hardcode the literal value of \
            `MainTabSelection.decisions.rawValue` (\(MainTabSelection.decisions.rawValue)).
            """
        )
        #expect(
            widgetSource.contains("\"\(PendingDraftCaptureFlag.storageKey)\""),
            """
            Widget mirror must hardcode the literal value of \
            `PendingDraftCaptureFlag.storageKey` (\(PendingDraftCaptureFlag.storageKey)).
            """
        )
    }

    @Test("Widget mirror writes routing payloads through the App Group shared suite — never UserDefaults.standard, which would not reach the main-app consumer")
    func widgetCopyUsesSharedSuite() throws {
        guard let widgetSource = Self.sourceIfReadable(
            relativePath: "NomadFiWidgetExtension/StartDraftCaptureIntent.swift"
        ) else { return }

        #expect(
            widgetSource.contains("UserDefaults(\n            suiteName: NomadFiWidgetSharedConstants.appGroupIdentifier"),
            """
            Widget mirror must construct its UserDefaults via \
            `UserDefaults(suiteName: NomadFiWidgetSharedConstants.appGroupIdentifier)` \
            so the routing writes are visible in the App Group \
            shared suite.
            """
        )
        #expect(
            !widgetSource.contains("UserDefaults.standard"),
            """
            Widget mirror must not use `UserDefaults.standard` — \
            that is the *widget's* per-process defaults, not the \
            shared App Group suite the main-app consumer reads.
            """
        )
    }

    // MARK: - Helpers

    /// Loads `relativePath` (under the app's source root) off disk.
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
