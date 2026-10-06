// AccountListViewModel.swift
// NomadFi
//
// State and actions behind Settings → Financial Setup → Accounts.

import Foundation
import OSLog
import SwiftData

/// Sorting, search, multi-selection and deletion for the account list.
///
/// Deletion is always two steps — request, then confirm — because it
/// cascades: an account's transactions and subscriptions go with it.
@MainActor
@Observable
final class AccountListViewModel {

    /// Filters by account or institution name.
    var searchText = ""

    /// Accounts ticked in edit mode.
    var selection: Set<PersistentIdentifier> = []

    /// Drives the confirmation alert.
    var isConfirmingDeletion = false

    /// The accounts the alert is asking about. Replaced by each new
    /// request, so a cancelled alert needs no clean-up.
    private(set) var pendingDeletion: [Account] = []

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "AccountList")

    // MARK: - Listing

    /// `accounts` matching the search, by institution and then name.
    func visibleAccounts(_ accounts: [Account]) -> [Account] {
        AccountListing.visible(accounts, matching: searchText)
    }

    // MARK: - Selection

    func isAllSelected(in visible: [Account]) -> Bool {
        AccountListing.isAllSelected(selection, in: visible)
    }

    /// Selects every visible account, or clears the selection if all
    /// already are.
    func toggleSelectAll(in visible: [Account]) {
        selection = AccountListing.toggledSelectAll(selection, in: visible)
    }

    // MARK: - Deletion

    /// Asks to delete `accounts`; nothing is deleted until confirmed.
    func requestDeletion(of accounts: [Account]) {
        guard !accounts.isEmpty else { return }
        pendingDeletion = accounts
        isConfirmingDeletion = true
    }

    /// Asks to delete the selected accounts among `accounts`.
    func requestDeletionOfSelection(from accounts: [Account]) {
        requestDeletion(of: AccountListing.selected(selection, from: accounts))
    }

    /// Deletes the pending accounts — and, by cascade, their
    /// transactions and subscriptions — then clears the selection.
    func confirmDeletion(in context: ModelContext) {
        for account in pendingDeletion {
            context.delete(account)
        }
        do {
            try context.save()
        } catch {
            Self.logger.error("Account deletion failed to save: \(error.localizedDescription, privacy: .public)")
        }
        selection.subtract(pendingDeletion.map(\.persistentModelID))
        pendingDeletion = []
    }

    /// "Delete Account?" or "Delete 3 Accounts?".
    var deletionTitle: String {
        pendingDeletion.count == 1 ? "Delete Account?" : "Delete \(pendingDeletion.count) Accounts?"
    }

    /// Names what goes with the accounts, because it cannot come back.
    var deletionMessage: String {
        pendingDeletion.count == 1
            ? "\(pendingDeletion[0].name)'s transactions and subscriptions are deleted with it. This can't be undone."
            : "Their transactions and subscriptions are deleted with them. This can't be undone."
    }

    // MARK: - Adding

    /// Inserts an account built from the add-account form.
    func add(_ draft: SettingsAccountDraft, to context: ModelContext) {
        let snapshotTimestamp: Date? = draft.hasSnapshotValue ? .now : nil
        let snapshotSource: FinancialSnapshotSource? = draft.hasSnapshotValue ? .userSnapshot : nil

        context.insert(
            Account(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                institutionName: draft.institutionName.trimmingCharacters(in: .whitespacesAndNewlines),
                accountType: draft.accountType,
                currencyCode: draft.currencyCode,
                jurisdiction: draft.jurisdictionCode,
                foreignTransactionFeePercent: draft.parsedForeignTransactionFeePercent,
                creditLimit: draft.accountType.isCreditCard ? draft.parsedCreditLimit : nil,
                currentBalance: draft.parsedCurrentBalance,
                availableCredit: draft.accountType.isCreditCard ? draft.parsedAvailableCredit : nil,
                financialSnapshotUpdatedAt: snapshotTimestamp,
                financialSnapshotSource: snapshotSource
            )
        )
    }
}
