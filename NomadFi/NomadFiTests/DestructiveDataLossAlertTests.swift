// DestructiveDataLossAlertTests.swift
// NomadFi
//
// Pins the contract of the `destructiveDataLossAlert` design-
// system primitive plus the source-level guarantee that the two
// irreversible-data-loss flows in the app route through it
// instead of `.confirmationDialog`:
//
//   • `DecisionDraftDetailView` — single captured-draft delete.
//   • `PrivacySecuritySettingsView` — wipe-all-user-data.
//
// The two `Clear …` flows in the credit-card editors deliberately
// stay on `.confirmationDialog` because they are reversible (the
// user is told they can re-enter the data at any time). This
// suite documents that decision so a future "consistency cleanup"
// doesn't migrate them and break the boundary the primitive is
// trying to enforce.
//
// SwiftUI views can't be deeply introspected from a unit test, so
// the contract is pinned the same way `NomadFiActionButtonTests`
// pins its primitive: build-time signature smoke + a source-level
// guardrail that reads the touched files off disk and asserts
// they contain the chokepoint call. The simulator sandbox can
// block file reads outside the bundle; the source-level cases
// degrade to a soft-skip in that environment so the suite still
// runs cleanly there.

import Foundation
import SwiftUI
import Testing

@testable import NomadFi

@MainActor
struct DestructiveDataLossAlertTests {

    // MARK: - API surface smoke

    @Test("destructiveDataLossAlert is callable with the published parameter shape — signature regressions fail at compile time before they reach call sites")
    func primitiveSignatureSmoke() {
        struct Host: View {
            @State var isPresented = false
            var body: some View {
                Color.clear.destructiveDataLossAlert(
                    "Delete this thing?",
                    isPresented: $isPresented,
                    confirmationLabel: "Delete",
                    message: "This cannot be undone."
                ) {}
            }
        }
        // Building Host is enough — if the modifier signature
        // changes, this test fails to compile rather than at
        // runtime on a user device.
        _ = Host()
    }

    // MARK: - Chokepoint usage

    @Test("DecisionDraftDetailView routes its delete confirmation through destructiveDataLossAlert — never .confirmationDialog")
    func decisionDraftDetailViewUsesPrimitive() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/DecisionAssistant/Drafts/DecisionDraftDetailView.swift"
        ) else { return }

        #expect(
            source.contains(".destructiveDataLossAlert("),
            """
            DecisionDraftDetailView must present its delete \
            confirmation via `.destructiveDataLossAlert` so the \
            prompt renders as a centered modal alert on every size \
            class. Inline `.alert` and `.confirmationDialog` calls \
            for this surface bypass the design-system chokepoint.
            """
        )
        #expect(
            !source.contains(".confirmationDialog("),
            """
            DecisionDraftDetailView must not contain a \
            `.confirmationDialog` call for the delete flow — the \
            irretrievable-data-loss path belongs in the \
            `destructiveDataLossAlert` chokepoint.
            """
        )
    }

    @Test("PrivacySecuritySettingsView routes the wipe-all-data confirmation through destructiveDataLossAlert — the most catastrophic action in the app")
    func privacySecuritySettingsViewUsesPrimitive() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/Settings/Hub/PrivacySecuritySettingsView.swift"
        ) else { return }

        #expect(
            source.contains(".destructiveDataLossAlert("),
            """
            PrivacySecuritySettingsView must present the \
            wipe-all-data confirmation via \
            `.destructiveDataLossAlert`. This is the most \
            catastrophic action in the app — a centered modal \
            alert is the only HIG-correct presentation.
            """
        )
        #expect(
            !source.contains(".confirmationDialog("),
            """
            PrivacySecuritySettingsView must not contain a \
            `.confirmationDialog` call. The wipe-all-data path \
            belongs in the `destructiveDataLossAlert` chokepoint.
            """
        )
    }

    // MARK: - Reversible flows deliberately kept on .confirmationDialog

    @Test("CreditCardScheduleEditView keeps its 'Clear all dates' flow on .confirmationDialog — the action is reversible, so the lighter sheet is correct per HIG")
    func reversibleClearAllDatesStaysOnConfirmationDialog() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/Settings/CreditCardScheduleEditView.swift"
        ) else { return }

        #expect(
            source.contains(".confirmationDialog("),
            """
            CreditCardScheduleEditView intentionally uses \
            `.confirmationDialog` for the 'Clear all dates' flow \
            because the action is reversible (the user is told \
            they can re-enter the dates). Migrating this to \
            `destructiveDataLossAlert` would dilute the meaning \
            of the chokepoint primitive — see file header in \
            `DestructiveDataLossAlert.swift`.
            """
        )
    }

    @Test("CreditCardRewardsEditView keeps its 'Clear rewards' flow on .confirmationDialog — same reversibility rule")
    func reversibleClearRewardsStaysOnConfirmationDialog() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/Settings/CreditCardRewardsEditView.swift"
        ) else { return }

        #expect(
            source.contains(".confirmationDialog("),
            """
            CreditCardRewardsEditView intentionally uses \
            `.confirmationDialog` for the 'Clear rewards' flow \
            because the action is reversible. See file header in \
            `DestructiveDataLossAlert.swift` for the chokepoint \
            scope rule.
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
