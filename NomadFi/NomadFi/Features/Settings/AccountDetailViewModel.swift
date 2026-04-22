// AccountDetailViewModel.swift
// NomadFi
//
// Owns the working state for the Account detail editor. Holds the
// persisted `Account` plus mirrored optional/decimal strings so the UI
// can bind to `TextField` without losing the distinction between
// "user cleared the field" and "user typed zero".

import Foundation
import Observation

/// View model behind ``AccountDetailView``.
@MainActor
@Observable
final class AccountDetailViewModel {

    // MARK: - Dependencies

    let account: Account

    /// Clock seam so tests can pin the snapshot timestamp deterministically.
    private let clock: () -> Date

    // MARK: - Profile

    var name: String
    var institutionName: String
    var accountType: AccountType
    var currencyCode: CurrencyCode
    var jurisdictionCode: String
    var foreignTransactionFeePercentText: String

    // MARK: - Credit card terms

    var creditLimitText: String
    var availableCreditText: String

    // MARK: - Latest snapshot

    var currentBalanceText: String
    var statementBalanceText: String

    // MARK: - Init

    init(
        account: Account,
        clock: @escaping () -> Date = { .now }
    ) {
        self.account = account
        self.clock = clock

        self.name = account.name
        self.institutionName = account.institutionName
        self.accountType = account.accountType ?? .checking
        self.currencyCode = account.currencyCode ?? .usd
        self.jurisdictionCode = account.jurisdiction
        self.foreignTransactionFeePercentText = account.foreignTransactionFeePercent == 0
            ? ""
            : String(account.foreignTransactionFeePercent)

        self.creditLimitText = Self.format(account.creditLimit)
        self.availableCreditText = Self.format(account.availableCredit)
        self.currentBalanceText = Self.format(
            account.currentBalance ?? (account.isCreditCard ? nil : (account.balance == 0 ? nil : account.balance))
        )
        self.statementBalanceText = Self.format(account.statementBalance)
    }

    // MARK: - Derived

    var isCreditCard: Bool { accountType.isCreditCard }

    /// Last saved snapshot source, defaulting to `.userSnapshot` for
    /// edits made from this editor — this sheet is explicit manual
    /// user entry.
    var snapshotSource: FinancialSnapshotSource {
        account.latestSnapshotSource == .unknown ? .userSnapshot : account.latestSnapshotSource
    }

    var snapshotLastUpdatedAt: Date? {
        account.financialSnapshotUpdatedAt
    }

    /// True when the account is a credit card that currently has a
    /// non-zero legacy ``Account/balance`` but no ``creditLimit`` set —
    /// the canonical mis-entered case ("I entered my limit as a
    /// balance"). Surfaces an offer-to-migrate button in the editor.
    var canMoveLegacyBalanceIntoLimit: Bool {
        isCreditCard
            && account.balance > 0
            && account.creditLimit == nil
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !institutionName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    /// Moves the legacy ``Account/balance`` value into
    /// ``Account/creditLimit``. Intentionally one-way and only exposed
    /// for credit cards with the conflict described in
    /// ``canMoveLegacyBalanceIntoLimit``.
    func moveLegacyBalanceIntoLimit() {
        guard canMoveLegacyBalanceIntoLimit else { return }
        creditLimitText = Self.format(account.balance)
        // Clear the now-meaningless legacy balance; a credit card's
        // current balance must come from an explicit snapshot field.
        account.balance = 0
    }

    /// Persists the working values back to the ``Account``. Stamps a
    /// fresh snapshot timestamp whenever the user changes any of the
    /// live amount fields so freshness queries stay honest.
    func save() {
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.institutionName = institutionName.trimmingCharacters(in: .whitespaces)
        account.accountTypeRawValue = accountType.rawValue
        account.currencyCodeRawValue = currencyCode.rawValue
        account.jurisdiction = jurisdictionCode
        account.foreignTransactionFeePercent = max(
            0,
            Double(foreignTransactionFeePercentText.trimmingCharacters(in: .whitespaces)) ?? 0
        )

        let previousSnapshotSignature = snapshotSignature(for: account)

        // Only credit cards carry credit-card-specific terms; clear
        // them on type downgrades to prevent stale mixed state.
        if isCreditCard {
            account.creditLimit = Self.parse(creditLimitText)
            account.availableCredit = Self.parse(availableCreditText)
            account.statementBalance = Self.parse(statementBalanceText)
            account.currentBalance = Self.parse(currentBalanceText)
        } else {
            account.creditLimit = nil
            account.availableCredit = nil
            account.statementBalance = nil
            account.currentBalance = Self.parse(currentBalanceText)
        }

        let newSnapshotSignature = snapshotSignature(for: account)
        let now = clock()
        if previousSnapshotSignature != newSnapshotSignature {
            if anySnapshotValueSet(in: account) {
                account.financialSnapshotUpdatedAt = now
                account.financialSnapshotSourceRawValue = FinancialSnapshotSource.userSnapshot.rawValue
            } else {
                account.financialSnapshotUpdatedAt = nil
                account.financialSnapshotSourceRawValue = nil
            }
        }

        account.lastUpdatedAt = now
    }

    /// Clears every snapshot field — the "I no longer trust this
    /// snapshot" path. The credit limit, as a profile fact, is never
    /// cleared from here (the user can delete it explicitly by
    /// emptying the field).
    func clearSnapshot() {
        currentBalanceText = ""
        statementBalanceText = ""
        availableCreditText = ""
    }

    // MARK: - Helpers

    /// Captures every field that participates in "is this a snapshot?"
    /// so ``save`` can detect an edit without string-by-string diffs.
    private func snapshotSignature(for account: Account) -> [Double?] {
        [
            account.currentBalance,
            account.availableCredit,
            account.statementBalance,
            account.isCreditCard ? account.creditLimit : nil,
        ]
    }

    private func anySnapshotValueSet(in account: Account) -> Bool {
        account.currentBalance != nil
            || account.availableCredit != nil
            || account.statementBalance != nil
    }

    private static func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(value)
    }

    private static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed), value >= 0 else {
            return nil
        }
        return value
    }
}
