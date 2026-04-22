// OpenDecisionAssistantIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Open the Decision Assistant in NomadFi."
// Routes a voice or Shortcuts launch straight to the Decisions tab
// without claiming NomadFi can answer a specific question yet.

import AppIntents
import Foundation

/// Opens NomadFi directly on the Decisions tab.
///
/// Keeps the voice surface honest: this intent never invents a
/// recommendation. It only performs navigation — the app's Decision
/// Assistant is what the user actually interacts with once open.
///
/// Uses `@AppStorage`-backed `MainTabSelection` routing: this intent
/// writes the target tab to `UserDefaults`, then `openAppWhenRun`
/// activates the app; `MainTabView` reads the same key reactively on
/// appearance and honours the requested tab.
struct OpenDecisionAssistantIntent: AppIntent {

    static let title: LocalizedStringResource = "Open Decision Assistant"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi directly on the Decisions tab."
    )

    /// Explicit app launch — the user is asking NomadFi to navigate.
    static let openAppWhenRun = true

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(
            MainTabSelection.decisions.rawValue,
            forKey: MainTabSelection.storageKey
        )
        let dialog = DecisionAssistantIntentDialog.openDecisionAssistant
        return .result(dialog: "\(dialog)")
    }
}
