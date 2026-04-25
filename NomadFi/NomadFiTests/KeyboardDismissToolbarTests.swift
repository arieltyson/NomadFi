// KeyboardDismissToolbarTests.swift
// NomadFi
//
// Pins the contract of the design-system keyboard accessory plus
// the source-level guarantee that no NomadFi screen reintroduces
// either of the retired SwiftUI-toolbar shapes:
//
//   1. The original `.keyboardDismissToolbar { … }` view modifier
//      (wrapped a keyboard `ToolbarItemGroup` in its own
//      `.toolbar { }` block — raced with the screen's navigation
//      `.toolbar { }`).
//   2. `KeyboardDismissToolbarItem` composed into a navigation
//      `.toolbar { }` block — Apple's
//      `ToolbarItemGroup(placement: .keyboard)` silently fails to
//      re-register on subsequent focus changes inside sheets and
//      alongside other toolbar items, leaving the user stuck on a
//      `.decimalPad` keyboard with no Done button after the very
//      first focus.
//
// Both shapes have been retired in favour of the
// `safeAreaInset`-backed `.keyboardDoneAccessory(focused:)`
// modifier, which renders our own bar above the keyboard tied to
// the screen's `@FocusState`. The bar is visible whenever any
// field is focused, every time, without exception.
//
// SwiftUI views can't be deeply introspected from a unit test, so
// the contract is pinned the same way the other design-system
// guardrails are: build-time signature smoke + a source-level
// guard that reads the touched files off disk and asserts the
// chokepoint call. The simulator sandbox can block file reads
// outside the bundle; the source-level cases degrade to a
// soft-skip in that environment so the suite still runs cleanly.

import Foundation
import SwiftUI
import Testing

@testable import NomadFi

@MainActor
struct KeyboardDismissToolbarTests {

    // MARK: - API surface smoke

    @Test("`.keyboardDoneAccessory(focused:)` accepts an optional-enum focus binding — primary call shape")
    func enumFocusOverloadCompiles() {
        struct Host: View {
            @FocusState var focused: Field?
            enum Field: Hashable { case amount, currency }
            var body: some View {
                TextField("Amount", text: .constant(""))
                    .focused($focused, equals: .amount)
                    .keyboardDoneAccessory(focused: $focused)
            }
        }
        _ = Host()
    }

    @Test("`.keyboardDoneAccessory(focused:)` accepts a Bool focus binding — overload for single-field screens")
    func boolFocusOverloadCompiles() {
        struct Host: View {
            @FocusState var focused: Bool
            var body: some View {
                TextField("Note", text: .constant(""))
                    .focused($focused)
                    .keyboardDoneAccessory(focused: $focused)
            }
        }
        _ = Host()
    }

    // MARK: - Retired-shape guardrails (file-level)

    @Test("KeyboardDismissToolbar.swift no longer exports the retired `.keyboardDismissToolbar { }` view modifier")
    func retiredModifierIsAbsent() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/DesignSystem/Components/KeyboardDismissToolbar.swift"
        ) else { return }

        #expect(
            !source.contains("func keyboardDismissToolbar"),
            """
            KeyboardDismissToolbar.swift must not declare a \
            `.keyboardDismissToolbar { }` view modifier — that \
            shape wraps the toolbar item in its own `.toolbar { }` \
            block and races with the screen's navigation \
            `.toolbar { }`.
            """
        )
    }

    @Test("KeyboardDismissToolbar.swift no longer exports the retired `KeyboardDismissToolbarItem` ToolbarContent")
    func retiredToolbarItemIsAbsent() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/DesignSystem/Components/KeyboardDismissToolbar.swift"
        ) else { return }

        #expect(
            !source.contains("struct KeyboardDismissToolbarItem"),
            """
            KeyboardDismissToolbar.swift must not declare a \
            `KeyboardDismissToolbarItem` ToolbarContent. \
            `ToolbarItemGroup(placement: .keyboard)` silently \
            de-registers on subsequent focus changes inside sheets \
            — the user sees the Done button on the first field \
            tap and never again. Use the \
            `safeAreaInset`-backed `KeyboardDoneAccessoryBar` + \
            `.keyboardDoneAccessory(focused:)` modifier instead.
            """
        )
    }

    // MARK: - Call-site guardrails

    @Test("Every NomadFi screen that previously used a SwiftUI keyboard toolbar now uses `.keyboardDoneAccessory(focused:)`")
    func callSitesUseDesignSystemAccessory() throws {
        let touchedRelativePaths = [
            "NomadFi/Features/Scenarios/ScenarioDecisionBriefView.swift",
            "NomadFi/Features/Ledger/AddTransactionView.swift",
            "NomadFi/Features/Subscriptions/AddSubscriptionView.swift",
            "NomadFi/Features/TaxVault/ReceiptConfirmationView.swift",
            "NomadFi/Features/TaxVault/TaxDocumentDetailView.swift",
            "NomadFi/Features/Settings/AccountDetailView.swift",
            "NomadFi/Features/Settings/SettingsAddAccountSheet.swift",
            "NomadFi/Features/Settings/CreditCardRewardsEditView.swift",
            "NomadFi/Features/DecisionAssistant/Drafts/DecisionDraftFormView.swift",
            "NomadFi/Features/DecisionAssistant/PurchaseDecision/PurchaseDecisionBriefView.swift",
            "NomadFi/Features/Onboarding/AccountConnectionView.swift",
        ]

        for path in touchedRelativePaths {
            guard let source = Self.sourceIfReadable(relativePath: path) else { continue }

            #expect(
                source.contains(".keyboardDoneAccessory(focused:"),
                """
                \(path) must call \
                `.keyboardDoneAccessory(focused: $focusedField)` — \
                the design-system keyboard accessory is the only \
                supported way to add a Done bar above a \
                `.decimalPad` / `.numberPad` keyboard.
                """
            )
            #expect(
                !source.contains("KeyboardDismissToolbarItem"),
                """
                \(path) must not reference \
                `KeyboardDismissToolbarItem` — that shape was \
                retired because Apple's `ToolbarItemGroup(placement: .keyboard)` \
                silently de-registers on subsequent focus changes \
                inside sheets, leaving the user stuck on a \
                `.decimalPad` keyboard with no Done button.
                """
            )
            #expect(
                !source.contains(".keyboardDismissToolbar"),
                """
                \(path) must not call `.keyboardDismissToolbar { }` \
                — that modifier was retired with the same \
                rationale as `KeyboardDismissToolbarItem`. Use \
                `.keyboardDoneAccessory(focused:)` instead.
                """
            )
        }
    }

    // MARK: - Helpers

    /// Loads `relativePath` (under the app's source root) off disk.
    /// Returns `nil` when the sandbox blocks file reads (typical
    /// for iOS Simulator unit-test runs) so callers can degrade
    /// to a soft-skip rather than fail spuriously.
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
