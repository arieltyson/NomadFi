// CheckNetWorthIntent.swift
// NomadFi
//
// Siri shortcut: "Hey Siri, what's my net worth?"
// Returns the user's global net worth from all accounts.

import AppIntents
import SwiftData

/// Reports the user's global net worth via Siri or Shortcuts.
///
/// Sums all account balances to provide a quick financial snapshot.
/// In a full implementation, this would include exchange rate conversion;
/// for now it sums raw balances as a starting point.
///
/// Usage: "Hey Siri, what's my net worth?"
struct CheckNetWorthIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Net Worth"

    static let description: IntentDescription = "Get your global net worth across all accounts."

    static let openAppWhenRun = false

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Account.self)
        let context = container.mainContext

        let descriptor = FetchDescriptor<Account>()
        let accounts = try context.fetch(descriptor)

        guard !accounts.isEmpty else {
            return .result(dialog: "You don't have any accounts set up yet. Open NomadFi to get started.")
        }

        // `netWorthContribution` treats credit-card limits as capacity
        // (never assets), credit-card balances as liabilities when
        // known, and credit cards without a snapshot as excluded —
        // callers that want the count of excluded cards can inspect
        // `isExcludedFromNetWorth` themselves.
        let totalBalance = accounts.reduce(0.0) { $0 + $1.netWorthContribution }
        let accountCount = accounts.count
        let excludedCount = accounts.filter(\.isExcludedFromNetWorth).count
        let primaryCurrency = accounts.first?.currencyCode ?? .usd
        let formatted = totalBalance.formatted(.currency(code: primaryCurrency.rawValue))

        let caveat: String
        if excludedCount > 0 {
            let cardWord = excludedCount == 1 ? "credit card" : "credit cards"
            caveat = " \(excludedCount) \(cardWord) with no saved balance \(excludedCount == 1 ? "is" : "are") not counted."
        } else {
            caveat = ""
        }

        return .result(
            dialog: "Your net worth across \(accountCount) account\(accountCount == 1 ? "" : "s") is approximately \(formatted).\(caveat)"
        )
    }
}
