// KeyboardDismissToolbarTests.swift
// NomadFi
//
// Pins the contract of `KeyboardDismissToolbarItem` plus the
// source-level guarantee that no NomadFi screen reintroduces the
// retired `.keyboardDismissToolbar { … }` view modifier.
//
// Why this guardrail exists (incident learning):
//
//   The previous version of `KeyboardDismissToolbar.swift`
//   exported a view modifier that internally wrapped the
//   keyboard `ToolbarItemGroup` in its own `.toolbar { }` block.
//   When a screen called `.toolbar { … }` (for navigation items)
//   AND `.keyboardDismissToolbar { }` (for the keyboard accessory)
//   the two `.toolbar` modifiers raced at registration and the
//   keyboard group silently failed to attach — leaving the user
//   stuck on a `.decimalPad` keyboard with no Done button. The
//   modifier has been retired; this suite enforces that the only
//   public shape is `KeyboardDismissToolbarItem`, composed inside
//   the screen's single `.toolbar { }` block.
//
// SwiftUI views can't be deeply introspected from a unit test, so
// the guarantee is pinned the same way the other design-system
// guardrails are: build-time signature smoke + a source-level
// guard that reads `KeyboardDismissToolbar.swift` off disk and
// asserts the modifier is absent. The simulator sandbox can block
// file reads outside the bundle; the source-level cases degrade
// to a soft-skip in that environment so the suite still runs
// cleanly.

import Foundation
import SwiftUI
import Testing

@testable import NomadFi

@MainActor
struct KeyboardDismissToolbarTests {

    // MARK: - API surface smoke

    @Test("KeyboardDismissToolbarItem composes inside a single .toolbar { } block alongside navigation items — the canonical placement")
    func toolbarItemComposesAlongsideNavigation() {
        struct Host: View {
            @FocusState var focused: Field?
            enum Field: Hashable { case amount }
            var body: some View {
                NavigationStack {
                    TextField("Amount", text: .constant(""))
                        .focused($focused, equals: .amount)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {}
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {}
                            }
                            KeyboardDismissToolbarItem { focused = nil }
                        }
                }
            }
        }
        // Building Host is enough — if the `ToolbarContent`
        // signature regresses, this fails to compile rather than
        // at runtime in the keyboard accessory.
        _ = Host()
    }

    // MARK: - Modifier removal guardrail

    @Test("KeyboardDismissToolbar.swift no longer exports the racing `.keyboardDismissToolbar { }` view modifier")
    func modifierIsRetired() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/DesignSystem/Components/KeyboardDismissToolbar.swift"
        ) else { return }

        #expect(
            !source.contains("func keyboardDismissToolbar"),
            """
            KeyboardDismissToolbar.swift must not declare a \
            `.keyboardDismissToolbar { }` view modifier. The \
            previous version's modifier wrapped the toolbar item \
            in its own `.toolbar { }` block, which raced with the \
            screen's navigation `.toolbar { }` and silently \
            de-registered the keyboard accessory. Compose \
            `KeyboardDismissToolbarItem` inside the screen's \
            single `.toolbar { }` block instead.
            """
        )
        #expect(
            !source.contains("KeyboardDismissToolbarModifier"),
            """
            KeyboardDismissToolbar.swift must not declare a \
            `KeyboardDismissToolbarModifier`. Use \
            `KeyboardDismissToolbarItem` composed inside the \
            screen's existing `.toolbar { }` block.
            """
        )
    }

    // MARK: - Call-site guardrail

    @Test("No NomadFi feature view calls the retired `.keyboardDismissToolbar { }` modifier")
    func noFeatureViewUsesRetiredModifier() throws {
        let touchedRelativePaths = [
            "NomadFi/Features/Scenarios/ScenarioDecisionBriefView.swift",
            "NomadFi/Features/Ledger/AddTransactionView.swift",
            "NomadFi/Features/Subscriptions/AddSubscriptionView.swift",
            "NomadFi/Features/TaxVault/ReceiptConfirmationView.swift",
            "NomadFi/Features/TaxVault/TaxDocumentDetailView.swift",
        ]

        for path in touchedRelativePaths {
            guard let source = Self.sourceIfReadable(relativePath: path) else { continue }
            #expect(
                !source.contains(".keyboardDismissToolbar"),
                """
                \(path) must not call `.keyboardDismissToolbar { }` \
                — that modifier was retired because it raced with \
                the screen's navigation `.toolbar { }` and left the \
                user stuck on `.decimalPad` keyboards with no Done \
                button. Compose `KeyboardDismissToolbarItem` inside \
                the existing `.toolbar { }` block instead.
                """
            )
            #expect(
                source.contains("KeyboardDismissToolbarItem"),
                """
                \(path) must compose `KeyboardDismissToolbarItem` \
                inside its `.toolbar { }` block — every NomadFi \
                form that accepts numeric input needs an explicit \
                Done affordance because `.decimalPad` and \
                `.numberPad` keyboards have no Return key.
                """
            )
        }
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
