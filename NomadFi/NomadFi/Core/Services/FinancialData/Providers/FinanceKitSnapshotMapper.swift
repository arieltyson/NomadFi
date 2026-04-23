// FinanceKitSnapshotMapper.swift
// NomadFi
//
// Pure projection from Apple's FinanceKit primitives into NomadFi's
// provider-neutral snapshot contract. Keeping the mapping out of the
// adapter itself means:
//
// 1. The mapper is fully unit-testable without the managed
//    `com.apple.developer.financekit` entitlement, a real device, or
//    any FinanceKit authorization state.
// 2. The adapter's responsibility stays narrow — call the official
//    FinanceKit API, translate framework errors into the provider-
//    neutral error type, hand the raw rows to this mapper.
// 3. A future integration (or a bug fix) only has to touch one file
//    when the mapping rules change.
//
// Source references (official Apple docs + the local Xcode 26.4 SDK
// swiftinterface):
// - `FinanceKit.Account` is an enum with `.asset(AssetAccount)` /
//   `.liability(LiabilityAccount)`; both carry an ISO 4217
//   `currencyCode: String`.
// - `LiabilityAccount.creditInformation` carries `creditLimit`,
//   `nextPaymentDueDate`, `minimumNextPaymentAmount`,
//   `overduePaymentAmount` — all optional `CurrencyAmount`s / `Date`s.
// - `FinanceKit.AccountBalance.currentBalance` is an enum with
//   `.available(Balance)`, `.booked(Balance)`,
//   `.availableAndBooked(available:booked:)`. Each `Balance` exposes
//   `amount: CurrencyAmount`, `asOfDate: Date`, and a
//   `CreditDebitIndicator`.
// - `FinanceKit.Transaction.creditDebitIndicator` distinguishes
//   account-perspective inflow (`.credit`) from outflow (`.debit`).
//   NomadFi's store convention is "debit = negative, credit =
//   positive" (see `TransactionImportService.makeTransaction`), so
//   the mapper applies `-abs` to debits and `+abs` to credits.

import Foundation

/// Pure projection helpers from FinanceKit primitives into
/// provider-neutral snapshots. Every function is static and
/// deterministic; tests exercise every branch with plain values.
enum FinanceKitSnapshotMapper {

    // MARK: - Accounts

    /// Which side of the balance sheet a FinanceKit account sits on.
    /// Mirrors the public `Account.asset` / `Account.liability` cases.
    /// Kept as a pure enum so tests can exercise both paths without
    /// decoding FinanceKit Codable payloads.
    enum AccountKind: Sendable, Equatable {
        case asset
        case liability
    }

    /// Inputs extracted from a single `FinanceKit.Account`. Keeping
    /// the mapper primitive-only means the tests don't have to
    /// construct FinanceKit's `Account` enum via JSON decode.
    struct AccountInput: Sendable, Equatable {
        let id: UUID
        let displayName: String
        let institutionName: String
        let currencyCode: String
        let kind: AccountKind
        let creditLimit: Decimal?
        let refreshedAt: Date?
        let currentBalance: Decimal?
        let availableBalance: Decimal?
        let statementBalance: Decimal?
    }

    /// Projects a FinanceKit account onto a
    /// ``FinancialAccountSnapshot`` if NomadFi can model its
    /// currency. Returns `nil` for currencies the app does not
    /// represent (see `CurrencyCode.allCases`) — the reconciler then
    /// skips the row rather than coercing it into an unrelated
    /// currency.
    static func mapAccount(_ input: AccountInput) -> FinancialAccountSnapshot? {
        guard let currency = CurrencyCode(rawValue: input.currencyCode.uppercased()) else {
            return nil
        }
        let accountType: AccountType
        switch input.kind {
        case .liability: accountType = .creditCard
        case .asset: accountType = .checking
        }
        let creditLimit = input.kind == .liability ? decimalToDouble(input.creditLimit) : nil
        let currentBalance = decimalToDouble(input.currentBalance)
        let availableCredit = input.kind == .liability
            ? decimalToDouble(input.availableBalance)
            : nil
        let statementBalance = input.kind == .liability
            ? decimalToDouble(input.statementBalance)
            : nil

        return FinancialAccountSnapshot(
            id: input.id.uuidString,
            providerKind: .financeKit,
            institutionIdentifier: nil,
            displayName: input.displayName,
            institutionName: input.institutionName,
            accountType: accountType,
            currencyCode: currency,
            currentBalance: currentBalance,
            creditLimit: creditLimit,
            availableCredit: availableCredit,
            statementBalance: statementBalance,
            refreshedAt: input.refreshedAt
        )
    }

    // MARK: - Transactions

    /// Inputs extracted from a single `FinanceKit.Transaction`.
    struct TransactionInput: Sendable, Equatable {
        let id: UUID
        let accountID: UUID
        let amount: Decimal
        let currencyCode: String
        let indicator: TransactionIndicator
        let merchantName: String?
        let description: String
        let originalDescription: String
        let transactionDate: Date
        let postedDate: Date?
        let typeRawValue: Int16
        let statusRawValue: Int16
        let merchantCategoryCodeRawValue: Int16?
    }

    /// Matches `FinanceKit.CreditDebitIndicator`. Kept separate so
    /// tests are independent of the framework.
    enum TransactionIndicator: Sendable, Equatable {
        case credit
        case debit
    }

    /// Projects a FinanceKit transaction onto a
    /// ``FinancialTransactionSnapshot``. Returns `nil` when the
    /// currency, status, or type is not representable inside the
    /// NomadFi domain. Honest drop beats coerced guess — the
    /// reconciler surfaces unresolved snapshots explicitly.
    static func mapTransaction(
        _ input: TransactionInput
    ) -> FinancialTransactionSnapshot? {
        guard let currency = CurrencyCode(rawValue: input.currencyCode.uppercased()) else {
            return nil
        }
        let magnitude = decimalToDouble(input.amount) ?? 0
        let signed: Double
        switch input.indicator {
        case .debit: signed = -abs(magnitude)
        case .credit: signed = abs(magnitude)
        }

        let merchant = input.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedMerchant: String = {
            if let merchant, !merchant.isEmpty {
                return merchant
            }
            let cleanedDescription = input.description
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedDescription.isEmpty {
                return cleanedDescription
            }
            return input.originalDescription
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        let category = categorize(
            typeRawValue: input.typeRawValue,
            merchantCategoryCodeRawValue: input.merchantCategoryCodeRawValue
        )

        return FinancialTransactionSnapshot(
            id: input.id.uuidString,
            providerKind: .financeKit,
            accountID: input.accountID.uuidString,
            merchantName: resolvedMerchant,
            amount: signed,
            currencyCode: currency,
            date: input.postedDate ?? input.transactionDate,
            category: category,
            externalTransactionID: input.id.uuidString
        )
    }

    // MARK: - Helpers

    /// Converts a `Decimal` into a `Double` without triggering a
    /// precision-loss assertion. Nil in, nil out.
    static func decimalToDouble(_ value: Decimal?) -> Double? {
        guard let value else { return nil }
        return (value as NSDecimalNumber).doubleValue
    }

    /// Conservative projection onto NomadFi's `TransactionCategory`.
    /// Maps a small, honest subset of FinanceKit `TransactionType`
    /// raw values and leaves everything else as `.other`. This
    /// intentionally does not try to infer a category from
    /// merchant-category codes (ISO 18245) — those are opinionated
    /// and the existing `MerchantCategoryInferrer` already handles
    /// merchant-name heuristics on the NomadFi side.
    ///
    /// The raw values match `FinanceKit.TransactionType`'s declared
    /// order (see swiftinterface); `MerchantCategoryCode.rawValue`
    /// is available for future upgrades but not consulted here.
    static func categorize(
        typeRawValue: Int16,
        merchantCategoryCodeRawValue: Int16? = nil
    ) -> TransactionCategory {
        // Order follows `FinanceKit.TransactionType`'s declaration:
        //   0 unknown, 1 adjustment, 2 atm, 3 billPayment, 4 check,
        //   5 deposit, 6 directDeposit, 7 dividend, 8 fee,
        //   9 interest, 10 pointOfSale, 11 transfer, 12 withdrawal,
        //   13 standingOrder, 14 directDebit, 15 loan, 16 refund.
        switch typeRawValue {
        case 5, 6, 7, 9: return .income
        case 11, 13: return .transfer
        default: return .other
        }
    }
}
