// PlaidSandboxSnapshotMapperTests.swift
// NomadFi
//
// Phase 5D follow-through coverage for the pure Plaid → provider-
// neutral mapper. Every test uses DTO fixtures only; no broker, no
// network, no Keychain. This pins the Plaid-shape → NomadFi-shape
// invariants a future Phase 5E or Akoya adapter has to preserve.

import Foundation
import Testing

@testable import NomadFi

struct PlaidSandboxSnapshotMapperTests {

    private static let refreshedAt = Date(timeIntervalSince1970: 1_714_000_000)

    // MARK: - Accounts

    @Test("Plaid credit account maps to credit card with owed balance + credit limit")
    func creditAccountMapsToCreditCard() {
        let account = PlaidAccount(
            accountID: "acct_credit_1",
            name: "Freedom Sandbox",
            officialName: "Plaid Sandbox Freedom",
            mask: "0123",
            type: .credit,
            subtype: "credit card",
            balances: PlaidBalances(
                current: 420.75,
                available: 4_579.25,
                limit: 5_000,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
        let snapshot = PlaidSandboxSnapshotMapper.mapAccount(
            account,
            institutionName: "First Platypus Bank",
            refreshedAt: Self.refreshedAt
        )
        #expect(snapshot != nil)
        if let snapshot {
            #expect(snapshot.accountType == .creditCard)
            #expect(snapshot.currencyCode == .usd)
            #expect(snapshot.currentBalance == 420.75)
            #expect(snapshot.availableCredit == 4_579.25)
            #expect(snapshot.creditLimit == 5_000)
            #expect(snapshot.institutionName == "First Platypus Bank")
            #expect(snapshot.providerKind == .externalAggregator(identifier: "plaid_sandbox"))
            #expect(snapshot.persistedSnapshotSource == .imported)
        }
    }

    @Test("Plaid depository account defaults to checking; savings subtype narrows to savings")
    func depositoryAccountMaps() {
        let checking = PlaidAccount(
            accountID: "acct_dep_1",
            name: "Plaid Checking",
            officialName: nil,
            mask: nil,
            type: .depository,
            subtype: "checking",
            balances: PlaidBalances(
                current: 1_200,
                available: 1_150,
                limit: nil,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
        #expect(
            PlaidSandboxSnapshotMapper.mapAccount(
                checking,
                institutionName: "Sandbox Bank",
                refreshedAt: Self.refreshedAt
            )?.accountType == .checking
        )

        let savings = PlaidAccount(
            accountID: "acct_dep_2",
            name: "Plaid Savings",
            officialName: nil,
            mask: nil,
            type: .depository,
            subtype: "savings",
            balances: PlaidBalances(
                current: 8_000,
                available: 8_000,
                limit: nil,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
        #expect(
            PlaidSandboxSnapshotMapper.mapAccount(
                savings,
                institutionName: "Sandbox Bank",
                refreshedAt: Self.refreshedAt
            )?.accountType == .savings
        )
    }

    @Test("Depository accounts do not expose a credit limit or available-credit slot")
    func depositoryHasNoCreditSlots() {
        let account = PlaidAccount(
            accountID: "acct_dep_3",
            name: "Plaid Checking",
            officialName: nil,
            mask: nil,
            type: .depository,
            subtype: "checking",
            balances: PlaidBalances(
                current: 400,
                available: 350,
                limit: nil,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
        let snapshot = PlaidSandboxSnapshotMapper.mapAccount(
            account,
            institutionName: "Sandbox Bank",
            refreshedAt: Self.refreshedAt
        )
        #expect(snapshot?.creditLimit == nil)
        #expect(snapshot?.availableCredit == nil)
        #expect(snapshot?.currentBalance == 400)
    }

    @Test("Loan accounts are honestly dropped — NomadFi has no loan type")
    func loanAccountIsDropped() {
        let account = PlaidAccount(
            accountID: "acct_loan_1",
            name: "Plaid Student Loan",
            officialName: nil,
            mask: nil,
            type: .loan,
            subtype: "student",
            balances: PlaidBalances(
                current: 25_000,
                available: nil,
                limit: nil,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
        #expect(
            PlaidSandboxSnapshotMapper.mapAccount(
                account,
                institutionName: "Sandbox Bank",
                refreshedAt: Self.refreshedAt
            ) == nil
        )
    }

    @Test("Unknown currencies short-circuit to nil, not coerced to USD")
    func unsupportedCurrencyIsDropped() {
        let account = PlaidAccount(
            accountID: "acct_jpy",
            name: "Yen Only",
            officialName: nil,
            mask: nil,
            type: .credit,
            subtype: nil,
            balances: PlaidBalances(
                current: 100,
                available: nil,
                limit: 200,
                isoCurrencyCode: "JPY",
                unofficialCurrencyCode: nil
            )
        )
        #expect(
            PlaidSandboxSnapshotMapper.mapAccount(
                account,
                institutionName: "Sandbox Bank",
                refreshedAt: Self.refreshedAt
            ) == nil
        )
    }

    @Test("Plaid investment and brokerage map to investment")
    func investmentAccountMaps() {
        let investment = PlaidAccount(
            accountID: "acct_inv",
            name: "Sandbox 401k",
            officialName: nil,
            mask: nil,
            type: .investment,
            subtype: "401k",
            balances: PlaidBalances(
                current: 12_000,
                available: nil,
                limit: nil,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
        let brokerage = PlaidAccount(
            accountID: "acct_bro",
            name: "Sandbox Brokerage",
            officialName: nil,
            mask: nil,
            type: .brokerage,
            subtype: nil,
            balances: PlaidBalances(
                current: 500,
                available: nil,
                limit: nil,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
        for candidate in [investment, brokerage] {
            let snapshot = PlaidSandboxSnapshotMapper.mapAccount(
                candidate,
                institutionName: "Sandbox Bank",
                refreshedAt: Self.refreshedAt
            )
            #expect(snapshot?.accountType == .investment)
            #expect(snapshot?.creditLimit == nil)
            #expect(snapshot?.availableCredit == nil)
        }
    }

    // MARK: - Transactions

    @Test("Plaid outflow-positive → NomadFi outflow-negative")
    func signConventionInverts() {
        let transaction = sampleTransaction(
            id: "txn_1",
            account: "acct_credit_1",
            amount: 12.50,
            currency: "USD",
            primary: "FOOD_AND_DRINK"
        )
        let snapshot = PlaidSandboxSnapshotMapper.mapTransaction(transaction)
        #expect(snapshot?.amount == -12.50)

        let credit = sampleTransaction(
            id: "txn_2",
            account: "acct_credit_1",
            amount: -25,
            currency: "USD",
            primary: "INCOME"
        )
        #expect(PlaidSandboxSnapshotMapper.mapTransaction(credit)?.amount == 25)
    }

    @Test("Merchant name falls back to description when merchant is nil")
    func merchantFallbackToName() {
        let transaction = PlaidTransaction(
            transactionID: "txn_noMerchant",
            accountID: "acct_1",
            amount: 5.0,
            isoCurrencyCode: "USD",
            unofficialCurrencyCode: nil,
            date: "2026-04-10",
            authorizedDate: nil,
            merchantName: nil,
            name: "Recurring Debit — Sample Service",
            pending: false,
            personalFinanceCategory: nil,
            paymentChannel: "online"
        )
        let snapshot = PlaidSandboxSnapshotMapper.mapTransaction(transaction)
        #expect(snapshot?.merchantName == "Recurring Debit — Sample Service")
    }

    @Test("Category mapping is narrow and maps FOOD_AND_DRINK → .food, INCOME → .income, etc.")
    func categoryMapping() {
        #expect(PlaidSandboxSnapshotMapper.mapCategory("FOOD_AND_DRINK") == .food)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("TRANSPORTATION") == .transport)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("TRAVEL") == .transport)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("RENT_AND_UTILITIES") == .utilities)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("MEDICAL") == .medical)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("ENTERTAINMENT") == .entertainment)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("GENERAL_MERCHANDISE") == .shopping)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("INCOME") == .income)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("TRANSFER_IN") == .transfer)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("TRANSFER_OUT") == .transfer)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("LOAN_PAYMENTS") == .transfer)
        #expect(PlaidSandboxSnapshotMapper.mapCategory("SOMETHING_NEW") == .other)
        #expect(PlaidSandboxSnapshotMapper.mapCategory(nil) == .other)
    }

    @Test("Transaction external ID round-trips as the external transaction ID the reconciler dedupes on")
    func externalIDIsTransactionID() {
        let transaction = sampleTransaction(
            id: "txn_dedupe_target",
            account: "acct_1",
            amount: 5,
            currency: "USD",
            primary: "FOOD_AND_DRINK"
        )
        let snapshot = PlaidSandboxSnapshotMapper.mapTransaction(transaction)
        #expect(snapshot?.externalTransactionID == "txn_dedupe_target")
        #expect(snapshot?.id == "txn_dedupe_target")
    }

    @Test("Transactions in unsupported currencies are honestly dropped")
    func unsupportedCurrencyTransactionIsDropped() {
        let transaction = sampleTransaction(
            id: "txn_jpy",
            account: "acct_jpy",
            amount: 100,
            currency: "JPY",
            primary: "FOOD_AND_DRINK"
        )
        #expect(PlaidSandboxSnapshotMapper.mapTransaction(transaction) == nil)
    }

    // MARK: - Helpers

    private func sampleTransaction(
        id: String,
        account: String,
        amount: Double,
        currency: String,
        primary: String
    ) -> PlaidTransaction {
        PlaidTransaction(
            transactionID: id,
            accountID: account,
            amount: amount,
            isoCurrencyCode: currency,
            unofficialCurrencyCode: nil,
            date: "2026-04-10",
            authorizedDate: nil,
            merchantName: "Sample Merchant",
            name: "Sample Merchant",
            pending: false,
            personalFinanceCategory: PlaidPersonalFinanceCategory(
                primary: primary,
                detailed: nil,
                confidenceLevel: "HIGH"
            ),
            paymentChannel: "in store"
        )
    }
}
