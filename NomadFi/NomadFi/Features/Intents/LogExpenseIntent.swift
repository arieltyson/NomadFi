// LogExpenseIntent.swift
// NomadFi
//
// Siri shortcut: "Hey Siri, I just spent $15 USD on lunch"
// Logs a transaction via voice command.

import AppIntents
import SwiftData

/// Logs a quick expense via Siri or Shortcuts.
///
/// Allows users to record transactions hands-free by specifying
/// the amount, currency, and optional category. Ideal for logging
/// purchases immediately after they happen.
///
/// Usage: "Hey Siri, I just spent $15 on lunch"
struct LogExpenseIntent: AppIntent {

    static let title: LocalizedStringResource = "Log Expense"

    static let description: IntentDescription = "Quickly log a transaction with an amount and category."

    /// Voice-first write. `.background` is the iOS 18+ replacement
    /// for the deprecated `openAppWhenRun = false`.
    static let supportedModes: IntentModes = .background

    // MARK: - Parameters

    @Parameter(title: "Amount", description: "The expense amount")
    var amount: Double

    @Parameter(title: "Currency", description: "The currency code (e.g., USD, CAD, TTD)")
    var currencyCode: String?

    @Parameter(title: "Merchant", description: "Where you spent the money")
    var merchant: String?

    @Parameter(title: "Category", description: "The expense category")
    var category: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedCurrency = CurrencyCode(rawValue: currencyCode?.uppercased() ?? "USD") ?? .usd
        let resolvedMerchant = merchant ?? "Quick Expense"
        let resolvedCategory = TransactionCategory(rawValue: category?.lowercased() ?? "other") ?? .other

        let container = try ModelContainer(for: Transaction.self)
        let context = container.mainContext

        let transaction = Transaction(
            merchantName: resolvedMerchant,
            originalAmount: -abs(amount),
            originalCurrency: resolvedCurrency,
            date: .now,
            category: resolvedCategory,
            createdAt: .now
        )

        context.insert(transaction)
        try context.save()

        let formatted = abs(amount).formatted(.money(code: resolvedCurrency.rawValue))
        return .result(
            dialog: "Logged \(formatted) at \(resolvedMerchant)."
        )
    }
}
