// AccountFinancialSnapshotTests.swift
// NomadFi
//
// Focused coverage for the Account snapshot + net-worth refactor:
// credit-card limits stay out of net worth, credit-card current
// balances count as liabilities when known, missing credit-card
// balances are excluded and labelled unknown, and non-credit accounts
// behave the same as before when migrated rows are loaded.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct AccountFinancialSnapshotTests {

    // MARK: - Helpers

    nonisolated private static func date(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Account.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    // MARK: - Existing initializer compatibility

    @Test("Existing Account initializers still compile and keep legacy balance semantics")
    func existingInitializerStillCompiles() {
        let account = Account(
            name: "Legacy Checking",
            institutionName: "Legacy Bank",
            accountType: .checking,
            currencyCode: .usd,
            balance: 125,
            jurisdiction: "US"
        )
        #expect(account.balance == 125)
        #expect(account.currentBalance == nil)
        #expect(account.creditLimit == nil)
        #expect(account.hasFinancialSnapshot == false)
        #expect(account.netWorthContribution == 125)
    }

    // MARK: - Credit card: limit is not an asset

    @Test("Credit limit alone is never counted as net worth")
    func creditLimitNotCountedAsNetWorth() {
        let account = Account(
            name: "Sample Rewards",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .cad,
            jurisdiction: "CA",
            creditLimit: 12_000
        )
        #expect(account.netWorthContribution == 0)
        #expect(account.isExcludedFromNetWorth)
    }

    @Test("Legacy credit card with value stuck in balance still contributes 0 to net worth")
    func creditLimitInLegacyBalanceExcluded() {
        // Simulates the exact AMEX-CAD-12000 migration case: the legacy
        // `balance` holds what was actually the credit limit. The
        // refactor treats unknown credit-card debt as excluded.
        let account = Account(
            name: "Legacy Amex",
            institutionName: "Legacy Issuer",
            accountType: .creditCard,
            currencyCode: .cad,
            balance: 12_000,
            jurisdiction: "CA"
        )
        #expect(account.netWorthContribution == 0)
        #expect(account.isExcludedFromNetWorth)
    }

    // MARK: - Credit card: known balance is a liability

    @Test("Credit card with known current balance counts as a liability")
    func creditCardBalanceCountsAsLiability() {
        let account = Account(
            name: "Sample Rewards",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000,
            currentBalance: 320.50,
            availableCredit: 4_679.50,
            financialSnapshotUpdatedAt: Self.date(year: 2026, month: 4, day: 20),
            financialSnapshotSource: .userSnapshot
        )
        #expect(account.netWorthContribution == -320.50)
        #expect(!account.isExcludedFromNetWorth)
        #expect(account.hasFinancialSnapshot)
    }

    // MARK: - Credit card: missing balance is honest unknown

    @Test("Credit card with no snapshot is excluded and labelled as unknown")
    func creditCardMissingSnapshotLabelsAsUnknown() {
        let account = Account(
            name: "Sample Cash Back",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .cad,
            jurisdiction: "CA",
            creditLimit: 5_000
        )
        #expect(account.isExcludedFromNetWorth)
        #expect(account.primaryAmountLabel.kind == .balanceUnknown)
        #expect(account.primaryAmountLabel.text == "Balance not set")
        #expect(account.primaryAmountLabel.accessibilityPhrase == "balance not set")
    }

    @Test("Credit card row labels the credit limit as a limit, never as a balance")
    func creditCardLabelsLimitHonestly() {
        let account = Account(
            name: "Sample Rewards",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .cad,
            jurisdiction: "CA",
            creditLimit: 12_000
        )
        let secondary = account.secondaryAmountLabel
        #expect(secondary?.kind == .creditLimit)
        #expect(secondary?.text.hasPrefix("Limit ") == true)
        #expect(secondary?.accessibilityPhrase.hasPrefix("credit limit ") == true)
        #expect(secondary?.accessibilityPhrase.contains("balance") == false)
    }

    // MARK: - Non-credit accounts

    @Test("Non-credit account with current-balance snapshot contributes the snapshot")
    func nonCreditSnapshotCountsAsAsset() {
        let account = Account(
            name: "Sample Checking",
            institutionName: "Sample Bank",
            accountType: .checking,
            currencyCode: .usd,
            jurisdiction: "US",
            currentBalance: 2_875,
            financialSnapshotUpdatedAt: Self.date(year: 2026, month: 4, day: 20),
            financialSnapshotSource: .userSnapshot
        )
        #expect(account.netWorthContribution == 2_875)
        #expect(!account.isExcludedFromNetWorth)
    }

    @Test("Non-credit account with only legacy balance still counts as before")
    func nonCreditLegacyBalanceStillCounts() {
        let account = Account(
            name: "Legacy Savings",
            institutionName: "Legacy Bank",
            accountType: .savings,
            currencyCode: .usd,
            balance: 4_100,
            jurisdiction: "US"
        )
        #expect(account.netWorthContribution == 4_100)
        #expect(!account.isExcludedFromNetWorth)
    }

    // MARK: - Snapshot staleness

    @Test("A snapshot older than the source's freshness window is marked stale")
    func snapshotMarkedStaleAfterWindow() {
        let ancient = Self.date(year: 2025, month: 1, day: 1)
        let now = Self.date(year: 2026, month: 4, day: 20)
        let account = Account(
            name: "Stale Wallet",
            institutionName: "Sample",
            accountType: .wallet,
            currencyCode: .usd,
            jurisdiction: "US",
            currentBalance: 50,
            financialSnapshotUpdatedAt: ancient,
            financialSnapshotSource: .userSnapshot
        )
        #expect(account.isFinancialSnapshotStale(now: now))
    }

    @Test("A fresh snapshot is not stale")
    func freshSnapshotNotStale() {
        let now = Self.date(year: 2026, month: 4, day: 20)
        let yesterday = Self.date(year: 2026, month: 4, day: 19)
        let account = Account(
            name: "Fresh Wallet",
            institutionName: "Sample",
            accountType: .wallet,
            currencyCode: .usd,
            jurisdiction: "US",
            currentBalance: 50,
            financialSnapshotUpdatedAt: yesterday,
            financialSnapshotSource: .userSnapshot
        )
        #expect(!account.isFinancialSnapshotStale(now: now))
    }

    // MARK: - Settings add-account draft

    @Test("Settings add-account draft routes credit-card amounts into the right fields")
    func addAccountDraftMapsCreditCardAmounts() {
        var draft = SettingsAccountDraft()
        draft.name = "Sample Rewards"
        draft.institutionName = "Sample Bank"
        draft.accountType = .creditCard
        draft.currencyCode = .cad
        draft.creditLimitText = "12000"
        draft.currentBalanceText = "450.25"
        draft.availableCreditText = "11549.75"

        #expect(draft.parsedCreditLimit == 12_000)
        #expect(draft.parsedCurrentBalance == 450.25)
        #expect(draft.parsedAvailableCredit == 11_549.75)
        #expect(draft.hasSnapshotValue)
    }

    @Test("Settings add-account draft treats blank credit-card balance as unset")
    func addAccountDraftLeavesBlankBalanceUnset() {
        var draft = SettingsAccountDraft()
        draft.accountType = .creditCard
        draft.creditLimitText = "5000"
        draft.currentBalanceText = ""
        draft.availableCreditText = ""

        #expect(draft.parsedCreditLimit == 5_000)
        #expect(draft.parsedCurrentBalance == nil)
        #expect(draft.parsedAvailableCredit == nil)
        #expect(!draft.hasSnapshotValue)
    }

    @Test("Settings add-account draft for non-credit account never populates credit-card fields")
    func nonCreditDraftHasNoCreditFields() {
        var draft = SettingsAccountDraft()
        draft.name = "Sample Checking"
        draft.institutionName = "Sample Bank"
        draft.accountType = .checking
        draft.currentBalanceText = "1500"

        #expect(draft.parsedCurrentBalance == 1_500)
        #expect(draft.parsedCreditLimit == nil)
        #expect(draft.parsedAvailableCredit == nil)
        #expect(draft.hasSnapshotValue)
    }

    // MARK: - Dashboard calculations

    @Test("Dashboard global net worth excludes credit limits and unknown credit balances")
    func globalNetWorthIgnoresCreditLimits() {
        let accounts: [Account] = [
            Account(
                name: "Savings",
                institutionName: "Bank A",
                accountType: .savings,
                currencyCode: .usd,
                jurisdiction: "US",
                currentBalance: 5_000,
                financialSnapshotSource: .userSnapshot
            ),
            Account(
                name: "Card A",
                institutionName: "Bank A",
                accountType: .creditCard,
                currencyCode: .usd,
                jurisdiction: "US",
                creditLimit: 10_000 // no current balance
            ),
            Account(
                name: "Card B",
                institutionName: "Bank B",
                accountType: .creditCard,
                currencyCode: .usd,
                jurisdiction: "US",
                creditLimit: 5_000,
                currentBalance: 250
            ),
        ]

        let viewModel = DashboardViewModel()
        let total = viewModel.globalNetWorth(accounts: accounts, homeCurrency: .usd)
        #expect(total == 5_000 - 250)
        #expect(viewModel.excludedCreditCardsCount(accounts: accounts) == 1)
    }

    @Test("Jurisdiction net worth for a credit-card-only region excludes unset balances")
    func jurisdictionNetWorthExcludesUnknownCreditCards() {
        let accounts: [Account] = [
            Account(
                name: "Card A",
                institutionName: "Bank A",
                accountType: .creditCard,
                currencyCode: .cad,
                jurisdiction: "CA",
                creditLimit: 12_000
            ),
            Account(
                name: "Chequing",
                institutionName: "Bank A",
                accountType: .checking,
                currencyCode: .cad,
                jurisdiction: "CA",
                currentBalance: 800
            ),
        ]
        let viewModel = DashboardViewModel()
        let total = viewModel.jurisdictionNetWorth(accounts: accounts, jurisdictionCode: "CA")
        #expect(total == 800)
    }

    // MARK: - Detail view model

    @Test("Detail view model migrates a legacy credit-card balance into credit limit")
    func detailViewModelMovesLegacyBalanceIntoLimit() {
        let account = Account(
            name: "Legacy Amex",
            institutionName: "Legacy Issuer",
            accountType: .creditCard,
            currencyCode: .cad,
            balance: 12_000,
            jurisdiction: "CA"
        )
        let viewModel = AccountDetailViewModel(
            account: account,
            clock: { Self.date(year: 2026, month: 4, day: 21) }
        )
        #expect(viewModel.canMoveLegacyBalanceIntoLimit)

        viewModel.moveLegacyBalanceIntoLimit()
        viewModel.save()

        #expect(account.creditLimit == 12_000)
        #expect(account.balance == 0)
        #expect(account.netWorthContribution == 0)
        #expect(account.isExcludedFromNetWorth)
    }

    @Test("Detail view model detects and strips trailing credit suffixes on credit cards")
    func detailViewModelStripsRedundantCreditSuffix() {
        let variants: [(input: String, expected: String)] = [
            ("Amex Cobalt Canada (Credit)", "Amex Cobalt Canada"),
            ("Chase Freedom Rise (Credit Card)", "Chase Freedom Rise"),
            ("CIBC Dividend - Credit", "CIBC Dividend"),
            ("CIBC Dividend – Credit", "CIBC Dividend"),
            ("Visa — Credit", "Visa"),
        ]

        for variant in variants {
            let account = Account(
                name: variant.input,
                institutionName: "Issuer",
                accountType: .creditCard,
                currencyCode: .cad,
                jurisdiction: "CA"
            )
            let viewModel = AccountDetailViewModel(account: account)
            #expect(viewModel.hasRedundantCreditSuffix, "Expected cleanup to be offered for \(variant.input)")
            #expect(viewModel.nameWithoutRedundantCreditSuffix == variant.expected)
            viewModel.stripRedundantCreditSuffix()
            #expect(viewModel.name == variant.expected)
            #expect(!viewModel.hasRedundantCreditSuffix)
        }
    }

    @Test("Detail view model never offers suffix cleanup for non-credit accounts")
    func detailViewModelDoesNotStripOnNonCreditAccounts() {
        let account = Account(
            name: "Joint Credit Line (Credit)",
            institutionName: "Bank",
            accountType: .checking,
            currencyCode: .usd,
            jurisdiction: "US"
        )
        let viewModel = AccountDetailViewModel(account: account)
        #expect(!viewModel.hasRedundantCreditSuffix)
        #expect(viewModel.nameWithoutRedundantCreditSuffix == nil)
    }

    @Test("Detail view model does not offer cleanup on already-clean credit card names")
    func detailViewModelLeavesCleanNamesAlone() {
        let account = Account(
            name: "Amex Cobalt Canada",
            institutionName: "American Express",
            accountType: .creditCard,
            currencyCode: .cad,
            jurisdiction: "CA"
        )
        let viewModel = AccountDetailViewModel(account: account)
        #expect(!viewModel.hasRedundantCreditSuffix)
    }

    @Test("Detail view model stamps snapshot timestamp and source when user edits a balance")
    func detailViewModelStampsSnapshotOnEdit() {
        let account = Account(
            name: "Chase Freedom Rise",
            institutionName: "Chase",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 500
        )
        let fixedNow = Self.date(year: 2026, month: 4, day: 21)
        let viewModel = AccountDetailViewModel(
            account: account,
            clock: { fixedNow }
        )
        viewModel.currentBalanceText = "125.00"
        viewModel.availableCreditText = "375.00"
        viewModel.save()

        #expect(account.currentBalance == 125)
        #expect(account.availableCredit == 375)
        #expect(account.financialSnapshotUpdatedAt == fixedNow)
        #expect(account.latestSnapshotSource == .userSnapshot)
    }

    // MARK: - SwiftData round-trip

    @Test("Snapshot fields round-trip through SwiftData")
    func snapshotFieldsRoundTrip() throws {
        let context = try makeInMemoryContext()
        let updatedAt = Self.date(year: 2026, month: 4, day: 20)
        let account = Account(
            name: "Sample Rewards",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000,
            currentBalance: 125,
            availableCredit: 4_875,
            statementBalance: 100,
            financialSnapshotUpdatedAt: updatedAt,
            financialSnapshotSource: .userSnapshot
        )
        context.insert(account)
        try context.save()

        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.name == "Sample Rewards" }
        )
        let fetched = try context.fetch(descriptor).first
        #expect(fetched?.creditLimit == 5_000)
        #expect(fetched?.currentBalance == 125)
        #expect(fetched?.availableCredit == 4_875)
        #expect(fetched?.statementBalance == 100)
        #expect(fetched?.financialSnapshotUpdatedAt == updatedAt)
        #expect(fetched?.latestSnapshotSource == .userSnapshot)
    }
}
