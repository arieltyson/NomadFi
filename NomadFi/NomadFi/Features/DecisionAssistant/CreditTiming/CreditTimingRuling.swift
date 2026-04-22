// CreditTimingRuling.swift
// NomadFi
//
// Top-level ruling for the Credit Timing engine. Derived from the
// worst per-card ruling so the Decision Assistant surface summarises
// the portfolio in a single honest sentence.

import Foundation

/// Portfolio-level summary of the Credit Timing engine's output.
enum CreditTimingRuling: String, Sendable, Equatable, CaseIterable {

    /// User has no credit-card accounts on file.
    case noCreditCardsOnFile

    /// At least one card is near its credit limit — the most urgent
    /// signal wins the summary.
    case someNearLimit

    /// No card is near the limit, but at least one card is above the
    /// conservative planning threshold and the engine suggests
    /// paydown before the statement closes.
    case somePayDownBeforeClose

    /// Core data (limit, current balance, schedule, snapshot freshness)
    /// is missing on one or more cards and no stronger signal
    /// outranks it. The UI surfaces the missing-data checklist.
    case missingData

    /// All cards are in a low / planning band with fresh data and
    /// confirmed schedules.
    case allCardsReady

    // MARK: - Display

    /// One-line summary used on the Decision Assistant hero.
    var displaySummary: String {
        switch self {
        case .noCreditCardsOnFile:
            "Add a credit card in Settings to use the Credit Timing engine."
        case .someNearLimit:
            "At least one card is near its credit limit. Avoid more spend on that card until the balance comes down."
        case .somePayDownBeforeClose:
            "At least one card would report a balance above a conservative planning target. Consider paying it down before statement close."
        case .missingData:
            "NomadFi needs more data before it can give a ruling for every card. Open the brief to see what's missing."
        case .allCardsReady:
            "All cards look ready. Continue paying the statement balance in full by the due date."
        }
    }
}
