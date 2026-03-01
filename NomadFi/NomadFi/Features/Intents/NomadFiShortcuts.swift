// NomadFiShortcuts.swift
// NomadFi
//
// Registers App Shortcuts for Siri and the Shortcuts app.
// Enables Lock Screen suggested shortcuts and voice activation.

import AppIntents

/// Provides NomadFi's App Shortcuts to the system.
///
/// These shortcuts appear in the Shortcuts app, Spotlight suggestions,
/// and can be triggered via Siri voice commands. They represent the
/// key financial operations users need quick access to.
struct NomadFiShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "I just spent money in \(.applicationName)",
                "Record a purchase in \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "dollarsign.circle"
        )

        AppShortcut(
            intent: CheckNetWorthIntent(),
            phrases: [
                "What's my net worth in \(.applicationName)",
                "Check my balance in \(.applicationName)",
                "How much money do I have in \(.applicationName)",
            ],
            shortTitle: "Check Net Worth",
            systemImageName: "globe"
        )

        AppShortcut(
            intent: ActiveCardIntent(),
            phrases: [
                "Which card should I use in \(.applicationName)",
                "What card to use in \(.applicationName)",
                "Best card for paying in \(.applicationName)",
            ],
            shortTitle: "Which Card?",
            systemImageName: "creditcard"
        )

        AppShortcut(
            intent: CheckBudgetIntent(),
            phrases: [
                "Check my budget in \(.applicationName)",
                "How much is left in my budget in \(.applicationName)",
                "Budget status in \(.applicationName)",
            ],
            shortTitle: "Check Budget",
            systemImageName: "chart.bar"
        )
    }
}
