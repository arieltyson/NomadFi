// KeyboardDoneToolbarTests.swift
// NomadFi
//
// Pins the contract of the design-system keyboard Done button.
//
// SwiftUI views can't be introspected from a unit test, so the
// contract is pinned the same way the other design-system
// guardrails are: build-time signature smoke plus a source-level
// guard that reads the touched files off disk. The simulator
// sandbox can block reads outside the bundle; those cases degrade
// to a soft-skip so the suite still runs cleanly. Behaviour across
// repeated focus changes is covered end to end by
// `NomadFiUITests.testKeyboardDoneSurvivesRepeatedFocusChanges`.

import Foundation
import SwiftUI
import Testing

@testable import NomadFi

@MainActor
struct KeyboardDoneToolbarTests {

    // MARK: - API surface smoke

    @Test("`.keyboardDone(_:)` accepts an optional-enum focus binding")
    func enumFocusOverloadCompiles() {
        struct Host: View {
            @FocusState var focused: Field?
            enum Field: Hashable { case amount, currency }
            var body: some View {
                NavigationStack {
                    TextField("Amount", text: .constant(""))
                        .focused($focused, equals: .amount)
                        .keyboardDone($focused)
                }
            }
        }
        _ = Host()
    }

    @Test("`.keyboardDone(_:)` accepts a Bool focus binding")
    func boolFocusOverloadCompiles() {
        struct Host: View {
            @FocusState var focused: Bool
            var body: some View {
                NavigationStack {
                    TextField("Note", text: .constant(""))
                        .focused($focused)
                        .keyboardDone($focused)
                }
            }
        }
        _ = Host()
    }

    // MARK: - Primitive guardrails

    @Test("The primitive pairs the Done button with drag-to-dismiss")
    func primitivePairsButtonWithGesture() {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/DesignSystem/Components/KeyboardDoneToolbar.swift"
        ) else { return }

        #expect(source.contains("placement: .keyboard"))
        #expect(source.contains(".scrollDismissesKeyboard(.interactively)"))
    }

    // MARK: - Call-site guardrails

    @Test("Every screen that raises a keyboard uses `.keyboardDone(_:)`")
    func callSitesUseDesignSystemModifier() {
        let paths = [
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

        for path in paths {
            guard let source = Self.sourceIfReadable(relativePath: path) else { continue }

            #expect(source.contains(".keyboardDone($"), "\(path) must call `.keyboardDone(_:)`.")
            #expect(
                !source.contains("placement: .keyboard"),
                "\(path) must not build its own keyboard toolbar; the primitive owns it."
            )
        }
    }

    // MARK: - Helpers

    /// Loads `relativePath` (under the app's source root) off disk,
    /// or returns `nil` when the sandbox blocks the read.
    private static func sourceIfReadable(relativePath: String) -> String? {
        let testsDir = URL(filePath: #filePath).deletingLastPathComponent()
        let roots = [
            testsDir.deletingLastPathComponent(),
            testsDir.deletingLastPathComponent().deletingLastPathComponent(),
        ]
        for url in roots.map({ $0.appending(path: relativePath) })
        where FileManager.default.fileExists(atPath: url.path()) {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        return nil
    }
}
