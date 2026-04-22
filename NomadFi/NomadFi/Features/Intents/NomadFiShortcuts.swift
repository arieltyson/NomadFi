// NomadFiShortcuts.swift
// NomadFi
//
// Registers App Shortcuts for Siri and the Shortcuts app.
// Enables Lock Screen suggested shortcuts and voice activation.
//
// The Decision Assistant shortcuts are intentionally honest about
// NomadFi's current coverage: today the deterministic engine only
// answers the Amazon arrival-order decision (Scenario 1). The legacy
// "Which card should I use?" phrase still routes to ``ActiveCardIntent``,
// but that intent now defers to the Scenario 1 engine rather than
// ranking accounts by foreign-transaction fee alone.

import AppIntents

/// Provides NomadFi's App Shortcuts to the system.
///
/// Shortcuts appear in the Shortcuts app, Spotlight suggestions, and
/// Siri voice. Order of appearance favours the decision-assistant
/// surfaces first; supporting shortcuts (net worth, budget, log
/// expense) follow.
struct NomadFiShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenDecisionAssistantIntent(),
            phrases: [
                "Open Decision Assistant in \(.applicationName)",
                "Open my decisions in \(.applicationName)",
                "Show my decision assistant in \(.applicationName)",
            ],
            shortTitle: "Open Decisions",
            systemImageName: "scale.3d"
        )

        AppShortcut(
            intent: ReviewAmazonArrivalDecisionIntent(),
            phrases: [
                "Review my Amazon order in \(.applicationName)",
                "Review my Amazon arrival decision in \(.applicationName)",
                "What's my Amazon order status in \(.applicationName)",
            ],
            shortTitle: "Review Amazon Order",
            systemImageName: "cart.fill.badge.plus"
        )

        AppShortcut(
            intent: ContinueAmazonArrivalDecisionIntent(),
            phrases: [
                "Continue my payment decision in \(.applicationName)",
                "Continue my Amazon decision in \(.applicationName)",
                "Finish my decision in \(.applicationName)",
            ],
            shortTitle: "Continue Decision",
            systemImageName: "arrow.forward.circle"
        )

        AppShortcut(
            intent: CaptureDecisionDraftIntent(),
            phrases: [
                "Capture a decision in \(.applicationName)",
                "Save a decision draft in \(.applicationName)",
                "Remember this financial decision in \(.applicationName)",
            ],
            shortTitle: "Capture Decision",
            systemImageName: "square.and.pencil"
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
            intent: CheckBudgetIntent(),
            phrases: [
                "Check my budget in \(.applicationName)",
                "How much is left in my budget in \(.applicationName)",
                "Budget status in \(.applicationName)",
            ],
            shortTitle: "Check Budget",
            systemImageName: "chart.bar"
        )

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
    }
}
