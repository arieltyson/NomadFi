// FinanceKitSnapshotMapperTests.swift
// NomadFi
//
// Phase 5C coverage for the pure FinanceKit → provider-neutral
// snapshot projection. Tests exercise every mapping branch without
// the managed `com.apple.developer.financekit` entitlement, a real
// device, or any live FinanceKit authorization.

import Foundation
import Testing

@testable import NomadFi

struct FinanceKitSnapshotMapperTests {

    private nonisolated static let sampleAccountID = UUID(
        uuidString: "6A3A2A0F-62C8-44DC-9710-4A5ABDCC6C5D"
    )!
    private nonisolated static let sampleTransactionID = UUID(
        uuidString: "B1D4D49B-4131-4A5B-80E9-C2D43A09E1F1"
    )!

    // MARK: - Accounts

    @Test("Liability mapping produces a credit card with credit info")
    func liabilityMapsToCreditCard() {
        let input = FinanceKitSnapshotMapper.AccountInput(
            id: Self.sampleAccountID,
            displayName: "Apple Card",
            institutionName: "Apple",
            currencyCode: "USD",
            kind: .liability,
            creditLimit: Decimal(5_000),
            refreshedAt: Date(timeIntervalSince1970: 1_714_000_000),
            currentBalance: Decimal(string: "120.50"),
            availableBalance: Decimal(string: "4879.50"),
            statementBalance: nil
        )
        let snapshot = FinanceKitSnapshotMapper.mapAccount(input)
        #expect(snapshot != nil)
        if let snapshot {
            #expect(snapshot.accountType == .creditCard)
            #expect(snapshot.currencyCode == .usd)
            #expect(snapshot.creditLimit == 5_000)
            #expect(snapshot.currentBalance == 120.50)
            #expect(snapshot.availableCredit == 4_879.50)
            #expect(snapshot.providerKind == .financeKit)
        }
    }

    @Test("Asset mapping produces a checking-kind account and never a credit limit")
    func assetMapsToChecking() {
        let input = FinanceKitSnapshotMapper.AccountInput(
            id: Self.sampleAccountID,
            displayName: "Apple Cash",
            institutionName: "Apple",
            currencyCode: "USD",
            kind: .asset,
            creditLimit: Decimal(9_999), // Should be ignored for assets.
            refreshedAt: nil,
            currentBalance: Decimal(string: "250.00"),
            availableBalance: nil,
            statementBalance: nil
        )
        let snapshot = FinanceKitSnapshotMapper.mapAccount(input)
        #expect(snapshot != nil)
        if let snapshot {
            #expect(snapshot.accountType == .checking)
            #expect(snapshot.creditLimit == nil)
            #expect(snapshot.availableCredit == nil)
            #expect(snapshot.currentBalance == 250)
        }
    }

    @Test("Unsupported currency short-circuits to nil instead of coercing USD")
    func unsupportedCurrencyReturnsNil() {
        let input = FinanceKitSnapshotMapper.AccountInput(
            id: Self.sampleAccountID,
            displayName: "Yen-Only Card",
            institutionName: "Fictional Bank",
            currencyCode: "JPY",
            kind: .liability,
            creditLimit: Decimal(500_000),
            refreshedAt: nil,
            currentBalance: Decimal(10),
            availableBalance: nil,
            statementBalance: nil
        )
        #expect(FinanceKitSnapshotMapper.mapAccount(input) == nil)
    }

    @Test("Lowercase currency codes are normalised")
    func lowercaseCurrencyIsCaseInsensitive() {
        let input = FinanceKitSnapshotMapper.AccountInput(
            id: Self.sampleAccountID,
            displayName: "Sample",
            institutionName: "Sample Bank",
            currencyCode: "gbp",
            kind: .asset,
            creditLimit: nil,
            refreshedAt: nil,
            currentBalance: Decimal(100),
            availableBalance: nil,
            statementBalance: nil
        )
        #expect(FinanceKitSnapshotMapper.mapAccount(input)?.currencyCode == .gbp)
    }

    // MARK: - Transactions

    @Test("Debit transactions are negative; credits are positive")
    func signConventionFollowsIndicator() {
        let base = FinanceKitSnapshotMapper.TransactionInput(
            id: Self.sampleTransactionID,
            accountID: Self.sampleAccountID,
            amount: Decimal(string: "12.50") ?? 0,
            currencyCode: "USD",
            indicator: .debit,
            merchantName: "Sample Cafe",
            description: "Sample Cafe NYC",
            originalDescription: "SQ *SAMPLE CAFE",
            transactionDate: Date(timeIntervalSince1970: 1_714_000_000),
            postedDate: nil,
            typeRawValue: 10, // pointOfSale
            statusRawValue: 3, // booked
            merchantCategoryCodeRawValue: nil
        )
        let debit = FinanceKitSnapshotMapper.mapTransaction(base)
        #expect(debit?.amount == -12.50)

        var credit = base
        credit = FinanceKitSnapshotMapper.TransactionInput(
            id: base.id,
            accountID: base.accountID,
            amount: base.amount,
            currencyCode: base.currencyCode,
            indicator: .credit,
            merchantName: base.merchantName,
            description: base.description,
            originalDescription: base.originalDescription,
            transactionDate: base.transactionDate,
            postedDate: base.postedDate,
            typeRawValue: base.typeRawValue,
            statusRawValue: base.statusRawValue,
            merchantCategoryCodeRawValue: base.merchantCategoryCodeRawValue
        )
        #expect(FinanceKitSnapshotMapper.mapTransaction(credit)?.amount == 12.50)
    }

    @Test("Posted date wins over transaction date when both are present")
    func postedDatePreferredOverTransactionDate() {
        let posted = Date(timeIntervalSince1970: 1_714_200_000)
        let transacted = Date(timeIntervalSince1970: 1_714_000_000)
        let input = FinanceKitSnapshotMapper.TransactionInput(
            id: Self.sampleTransactionID,
            accountID: Self.sampleAccountID,
            amount: Decimal(10),
            currencyCode: "USD",
            indicator: .debit,
            merchantName: "Sample",
            description: "",
            originalDescription: "",
            transactionDate: transacted,
            postedDate: posted,
            typeRawValue: 10,
            statusRawValue: 3,
            merchantCategoryCodeRawValue: nil
        )
        let snapshot = FinanceKitSnapshotMapper.mapTransaction(input)
        #expect(snapshot?.date == posted)
    }

    @Test("Empty merchant name falls back to description, then original description")
    func merchantFallbackOrder() {
        let base = FinanceKitSnapshotMapper.TransactionInput(
            id: Self.sampleTransactionID,
            accountID: Self.sampleAccountID,
            amount: Decimal(5),
            currencyCode: "USD",
            indicator: .debit,
            merchantName: nil,
            description: "Clean Description",
            originalDescription: "SQ *DIRTY ORIGINAL",
            transactionDate: Date(timeIntervalSince1970: 1_714_000_000),
            postedDate: nil,
            typeRawValue: 10,
            statusRawValue: 3,
            merchantCategoryCodeRawValue: nil
        )
        #expect(FinanceKitSnapshotMapper.mapTransaction(base)?.merchantName == "Clean Description")

        let fallback = FinanceKitSnapshotMapper.TransactionInput(
            id: base.id,
            accountID: base.accountID,
            amount: base.amount,
            currencyCode: base.currencyCode,
            indicator: base.indicator,
            merchantName: "   ",
            description: "",
            originalDescription: "SQ *DIRTY ORIGINAL",
            transactionDate: base.transactionDate,
            postedDate: base.postedDate,
            typeRawValue: base.typeRawValue,
            statusRawValue: base.statusRawValue,
            merchantCategoryCodeRawValue: nil
        )
        #expect(FinanceKitSnapshotMapper.mapTransaction(fallback)?.merchantName == "SQ *DIRTY ORIGINAL")
    }

    @Test("Unsupported transaction currency is dropped instead of coerced")
    func unsupportedTransactionCurrencyReturnsNil() {
        let input = FinanceKitSnapshotMapper.TransactionInput(
            id: Self.sampleTransactionID,
            accountID: Self.sampleAccountID,
            amount: Decimal(10),
            currencyCode: "JPY",
            indicator: .debit,
            merchantName: "Sample",
            description: "",
            originalDescription: "",
            transactionDate: Date(timeIntervalSince1970: 1_714_000_000),
            postedDate: nil,
            typeRawValue: 10,
            statusRawValue: 3,
            merchantCategoryCodeRawValue: nil
        )
        #expect(FinanceKitSnapshotMapper.mapTransaction(input) == nil)
    }

    @Test("Category mapping only lights up for the narrow FinanceKit types we recognize")
    func categoryMappingIsConservative() {
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 10) == .other)          // pointOfSale
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 3) == .other)           // billPayment
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 5) == .income)          // deposit
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 6) == .income)          // directDeposit
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 7) == .income)          // dividend
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 9) == .income)          // interest
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 11) == .transfer)       // transfer
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 13) == .transfer)       // standingOrder
        #expect(FinanceKitSnapshotMapper.categorize(typeRawValue: 0) == .other)           // unknown
    }

    // MARK: - Decimal helper

    @Test("Decimal → Double helper preserves nil")
    func decimalHelperPreservesNil() {
        #expect(FinanceKitSnapshotMapper.decimalToDouble(nil) == nil)
        #expect(FinanceKitSnapshotMapper.decimalToDouble(Decimal(string: "12.34"))?.rounded(toPlaces: 2) == 12.34)
    }
}

// MARK: - Helpers

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
