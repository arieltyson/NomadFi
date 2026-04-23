// NomadFiShortcuts.swift
// NomadFi
//
// Registers App Shortcuts for Siri and the Shortcuts app.
// Enables Lock Screen suggested shortcuts and voice activation.
//
// Voice parity with the in-app Decision Assistant:
//   - Amazon arrival-order review & continue — Scenario 1 engine.
//   - Capture decision draft — local-only voice intake.
//   - Recommend a card — generic `PurchaseDecisionEngine` answer.
//   - Review credit timing — portfolio-level `CreditTimingDecisionEngine`.
//
// Generic "Which card should I use…" phrases now route to
// ``RecommendCardIntent``, not the legacy ``ActiveCardIntent``.
// `ActiveCardIntent` remains as a deprecated type so existing
// user-built Shortcuts referencing it keep resolving, but it is no
// longer discoverable through this provider's default catalog.

import AppIntents

/// Provides NomadFi's App Shortcuts to the system.
///
/// Shortcuts appear in the Shortcuts app, Spotlight suggestions, and
/// Siri voice. Order favours the decision-assistant surfaces first;
/// supporting shortcuts (net worth, budget, log expense) follow.
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
            intent: RecommendCardIntent(),
            phrases: [
                "Which card should I use in \(.applicationName)",
                "What card to use in \(.applicationName)",
                "Recommend a card in \(.applicationName)",
            ],
            shortTitle: "Recommend a Card",
            systemImageName: "creditcard.and.123"
        )

        AppShortcut(
            intent: ReviewCreditTimingIntent(),
            phrases: [
                "Review my credit timing in \(.applicationName)",
                "Check my statement close readiness in \(.applicationName)",
                "How are my credit cards doing in \(.applicationName)",
            ],
            shortTitle: "Review Credit Timing",
            systemImageName: "calendar.badge.clock"
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
