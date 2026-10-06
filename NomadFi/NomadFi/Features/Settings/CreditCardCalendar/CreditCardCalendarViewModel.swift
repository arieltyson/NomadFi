// CreditCardCalendarViewModel.swift
// NomadFi
//
// State and actions behind Settings → Financial Setup → Credit Card
// Calendar.

import Foundation
import OSLog
import SwiftData

/// Search, multi-selection and clearing for the credit-card calendar.
///
/// Clearing is two steps — request, then confirm — because the dates
/// have to be looked up again in each issuer's app to restore them.
@MainActor
@Observable
final class CreditCardCalendarViewModel {

    /// Filters by card or institution name.
    var searchText = ""

    /// Cards ticked in edit mode.
    var selection: Set<PersistentIdentifier> = []

    /// Drives the confirmation alert.
    var isConfirmingClear = false

    /// The cards the alert is asking about. Replaced by each new
    /// request, so a cancelled alert needs no clean-up.
    private(set) var pendingClear: [Account] = []

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "CreditCardCalendar")

    // MARK: - Listing

    /// The credit cards among `accounts` that match the search.
    func visibleCards(_ accounts: [Account]) -> [Account] {
        AccountListing.visible(accounts.filter(\.isCreditCard), matching: searchText)
    }

    // MARK: - Selection

    func isAllSelected(in visible: [Account]) -> Bool {
        AccountListing.isAllSelected(selection, in: visible)
    }

    func toggleSelectAll(in visible: [Account]) {
        selection = AccountListing.toggledSelectAll(selection, in: visible)
    }

    // MARK: - Clearing

    /// Asks to clear the selected cards' dates; nothing changes until
    /// confirmed.
    func requestClearOfSelection(from cards: [Account]) {
        let selected = AccountListing.selected(selection, from: cards)
        guard !selected.isEmpty else { return }
        pendingClear = selected
        isConfirmingClear = true
    }

    /// Removes every statement date from the pending cards.
    func confirmClear(in context: ModelContext, now: Date = .now) {
        for card in pendingClear {
            CreditCardSchedule().apply(to: card, now: now)
        }
        do {
            try context.save()
        } catch {
            Self.logger.error("Clearing card dates failed to save: \(error.localizedDescription, privacy: .public)")
        }
        selection = []
        pendingClear = []
    }

    /// "Clear Dates?" or "Clear Dates for 3 Cards?".
    var clearTitle: String {
        pendingClear.count == 1 ? "Clear Dates?" : "Clear Dates for \(pendingClear.count) Cards?"
    }

    var clearMessage: String {
        pendingClear.count == 1
            ? "Every statement date for \(pendingClear[0].name) is removed. You'll need your issuer's app to enter them again."
            : "Every statement date for these cards is removed. You'll need each issuer's app to enter them again."
    }
}
