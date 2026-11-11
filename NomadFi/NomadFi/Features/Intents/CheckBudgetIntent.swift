// CheckBudgetIntent.swift
// NomadFi
//
// Siri shortcut: "Hey Siri, how much is left in my budget?"
// Reports current budget status.

import AppIntents
import SwiftData

/// Reports the user's current budget status via Siri or Shortcuts.
///
/// Fetches the most recent budget and reports how much has been
/// spent versus the budget limit. Provides a quick financial
/// pulse-check without opening the app.
///
/// Usage: "Hey Siri, how much is left in my budget?"
struct CheckBudgetIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Budget"

    static let description: IntentDescription = "Check how much you have left in your budget."

    /// Voice-only read. `.background` is the iOS 18+ replacement
    /// for the deprecated `openAppWhenRun = false`.
    static let supportedModes: IntentModes = .background

    /// Financial data never answers, or changes, from a locked iPhone:
    /// Siri and Shortcuts ask for Face ID, Touch ID or the passcode first.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Budget.self)
        let context = container.mainContext

        var budgetDescriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        budgetDescriptor.fetchLimit = 1
        let budgets = try context.fetch(budgetDescriptor)

        guard let budget = budgets.first else {
            return .result(dialog: "You don't have any budgets set up. Open NomadFi to create one.")
        }

        let remaining = budget.remainingAmount
        let percentage = budget.spentFraction * 100
        let currency = budget.currencyCode ?? .usd
        let remainingFormatted = remaining.formatted(.money(code: currency.rawValue))
        let percentFormatted = percentage.formatted(.number.precision(.fractionLength(0)))

        if !budget.isOverBudget {
            return .result(
                dialog: "You have \(remainingFormatted) left in your \(budget.name.isEmpty ? "" : "\(budget.name) ")budget. You've used \(percentFormatted)%."
            )
        } else {
            let overBy = (budget.spentAmount - budget.limitAmount)
                .formatted(.money(code: currency.rawValue))
            return .result(
                dialog: "You've exceeded your \(budget.name.isEmpty ? "" : "\(budget.name) ")budget by \(overBy). Consider reviewing your spending."
            )
        }
    }
}
