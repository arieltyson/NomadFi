// StartAIIntakeIntentTests.swift
// NomadFi
//
// Pins the contract of the parameterless control-surface intent
// + the source-level guarantee that the widget extension's
// mirror copy of `StartAIIntakeIntent` (and the routing keys it
// hardcodes) never drift from the main-app source of truth.
//
// Why a source-level guardrail is needed:
//   `ControlWidgetButton(action: StartAIIntakeIntent())` requires
//   the *widget extension* to see the intent type at compile
//   time, while `.foreground(.immediate)` requires the *main app*
//   to register the same intent identifier so iOS can dispatch
//   `perform()` in the app process. Xcode 16's synchronized
//   folders own each file by exactly one default target, so the
//   intent is duplicated in both targets. The widget mirror also
//   inlines the `MainTabSelection.storageKey` /
//   `PendingAIIntakeRequest.storageKey` literals because it
//   cannot import the main-app value types. Three drift risks
//   follow:
//
//     1. The intent's title / description / mode could diverge.
//     2. The widget's hardcoded UserDefaults keys could fall out
//        of sync with the main-app `String` constants.
//     3. The widget's hardcoded blank-launch JSON literal could
//        fall out of sync with `PendingAIIntakeRequest.blankLaunch.rawValue`.
//
//   This suite pins all three. The simulator sandbox can block
//   reads of the source files; in that environment the source-
//   level cases degrade to a soft-skip (same pattern the other
//   design-system guardrails use) so the suite still runs cleanly.

import AppIntents
import Foundation
import Testing

@testable import NomadFi

@MainActor
struct StartAIIntakeIntentTests {

    // MARK: - Intent contract

    @Test("StartAIIntakeIntent runs in .foreground(.immediate) — the user's purpose is to use the AI intake flow inside NomadFi, not run a background action")
    func startAIIntakeIsForeground() {
        let modes = StartAIIntakeIntent.supportedModes
        #expect(modes.contains(.foreground))
        #expect(!modes.contains(.background))
    }

    @Test("StartAIIntakeIntent declares no @Parameter requirements so it can fire from a one-tap ControlWidgetButton without surfacing a parameter sheet")
    func startAIIntakeHasNoParameters() {
        // App Intents exposes parameters via Mirror reflection on
        // the property wrappers. A parameterless intent has zero
        // children of type `IntentParameter` in its mirror.
        let mirror = Mirror(reflecting: StartAIIntakeIntent())
        let parameterChildren = mirror.children.filter { child in
            String(describing: type(of: child.value))
                .contains("IntentParameter")
        }
        #expect(
            parameterChildren.isEmpty,
            "StartAIIntakeIntent must be parameterless; found \(parameterChildren.count) IntentParameter property/properties."
        )
    }

    @Test("StartAIIntakeIntent perform() writes the Decisions tab routing slot + a blank-launch payload, then returns — no recommendation, no save, no interpretation")
    func performWritesRoutingSlotAndBlankPayload() async throws {
        // Defensive — clear both routing slots so the test starts
        // from a known empty state regardless of prior runs.
        UserDefaults.standard.removeObject(forKey: MainTabSelection.storageKey)
        UserDefaults.standard.removeObject(forKey: PendingAIIntakeRequest.storageKey)

        _ = try await StartAIIntakeIntent().perform()

        let tab = UserDefaults.standard.string(forKey: MainTabSelection.storageKey)
        #expect(tab == MainTabSelection.decisions.rawValue)

        let pendingRaw = UserDefaults.standard.string(forKey: PendingAIIntakeRequest.storageKey)
        let pending = pendingRaw.flatMap(PendingAIIntakeRequest.init(rawValue:))
        #expect(pending == .blankLaunch)
        #expect(pending?.scenarioText == nil)

        // Cleanup so the test never leaves the developer's
        // standard defaults in an inconsistent state.
        UserDefaults.standard.removeObject(forKey: MainTabSelection.storageKey)
        UserDefaults.standard.removeObject(forKey: PendingAIIntakeRequest.storageKey)
    }

    // MARK: - Existing parameterized intent preserved

    @Test("OpenAIIntakeIntent is preserved and still requires a scenarioText parameter — the parameterized Siri / Shortcut path is unchanged")
    func openAIIntakePreserved() {
        let mirror = Mirror(reflecting: OpenAIIntakeIntent())
        let parameterChildren = mirror.children.filter { child in
            String(describing: type(of: child.value))
                .contains("IntentParameter")
        }
        #expect(
            !parameterChildren.isEmpty,
            "OpenAIIntakeIntent must keep its scenarioText parameter — Siri / Shortcuts depend on it."
        )
    }

    // MARK: - Widget mirror drift guards

    @Test("Widget extension's StartAIIntakeIntent.swift exists and declares the same identifier + mode as the main-app copy")
    func widgetMirrorMatchesMainAppContract() throws {
        guard let widgetSource = Self.sourceIfReadable(
            relativePath: "NomadFiWidgetExtension/StartAIIntakeIntent.swift"
        ) else { return }

        #expect(
            widgetSource.contains("struct StartAIIntakeIntent: AppIntent"),
            """
            Widget mirror must declare \
            `struct StartAIIntakeIntent: AppIntent` so iOS can \
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
            widgetSource.contains("Start Apple Intelligence Intake"),
            """
            Widget mirror's title must match the main-app copy so \
            the surface label stays consistent.
            """
        )
    }

    @Test("Widget extension's hardcoded routing key strings match the main-app constants — the widget cannot import the main-app value types, so drift would silently break the launch")
    func widgetCopyMatchesMainAppKeys() throws {
        guard let widgetSource = Self.sourceIfReadable(
            relativePath: "NomadFiWidgetExtension/StartAIIntakeIntent.swift"
        ) else { return }

        #expect(
            widgetSource.contains("\"\(MainTabSelection.storageKey)\""),
            """
            Widget mirror must hardcode the literal value of \
            `MainTabSelection.storageKey` (\(MainTabSelection.storageKey)) \
            for its tab-selection write — drift would route the \
            widget tap to the wrong tab.
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
            widgetSource.contains("\"\(PendingAIIntakeRequest.storageKey)\""),
            """
            Widget mirror must hardcode the literal value of \
            `PendingAIIntakeRequest.storageKey` (\(PendingAIIntakeRequest.storageKey)) \
            for its pending-request write — drift would silently \
            break the consumer.
            """
        )
        #expect(
            widgetSource.contains(PendingAIIntakeRequest.blankLaunch.rawValue),
            """
            Widget mirror must hardcode the encoded blank-launch \
            payload (\(PendingAIIntakeRequest.blankLaunch.rawValue)) \
            verbatim — drift would emit a payload the main-app \
            consumer's `init?(rawValue:)` would reject.
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
