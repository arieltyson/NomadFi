// PlaidSandboxSnapshotMapper.swift
// NomadFi
//
// Pure projection from Plaid sandbox DTOs onto NomadFi's
// provider-neutral snapshot contract. Every rule is documented inline
// so a future engineer can audit the mapping without rereading Plaid's
// docs.
//
// Mapping rules (derived from primary Plaid docs):
// - Plaid `amount` is outflow-positive, inflow-negative (per
//   https://plaid.com/docs/api/products/transactions/). NomadFi's
//   domain convention is outflow-negative, inflow-positive. The
//   mapper inverts the sign.
// - `PlaidAccountType.credit` → `.creditCard` with Plaid's `current`
//   mapped to `currentBalance` (owed), `limit` to `creditLimit`, and
//   `available` to `availableCredit`.
// - `PlaidAccountType.depository` → `.checking` by default; subtype
//   `"savings"` narrows to `.savings`.
// - `PlaidAccountType.investment` / `.brokerage` → `.investment`.
// - `PlaidAccountType.loan` → **skipped**. NomadFi's domain model
//   does not carry loans as a first-class account type; coercing
//   would misrepresent them.
// - Currencies outside `CurrencyCode.allCases` are honestly dropped.
// - `personal_finance_category.primary` maps onto NomadFi's
//   `TransactionCategory` conservatively. Unknown primaries fall
//   through to `.other`. The mapper does not invent a category when
//   the upstream row has none.

import Foundation

enum PlaidSandboxSnapshotMapper {

    // MARK: - Accounts

    static func mapAccount(
        _ account: PlaidAccount,
        institutionName: String,
        refreshedAt: Date
    ) -> FinancialAccountSnapshot? {
        guard let currency = resolvedCurrency(
            iso: account.balances.isoCurrencyCode,
            unofficial: account.balances.unofficialCurrencyCode
        ) else {
            return nil
        }
        guard let accountType = mapAccountType(account: account) else {
            return nil
        }

        let displayName: String = {
            if let official = account.officialName, !official.isEmpty {
                return official
            }
            return account.name
        }()

        let isLiability = accountType == .creditCard
        let currentBalance = account.balances.current
        let availableCredit = isLiability ? account.balances.available : nil
        let creditLimit = isLiability ? account.balances.limit : nil

        return FinancialAccountSnapshot(
            id: account.accountID,
            providerKind: .externalAggregator(identifier: providerIdentifier),
            institutionIdentifier: nil,
            displayName: displayName,
            institutionName: institutionName,
            accountType: accountType,
            currencyCode: currency,
            currentBalance: currentBalance,
            creditLimit: creditLimit,
            availableCredit: availableCredit,
            statementBalance: nil,
            refreshedAt: refreshedAt
        )
    }

    /// Projects a Plaid account type + subtype onto NomadFi's
    /// ``AccountType``. Returns `nil` for upstream shapes NomadFi does
    /// not model (loans today).
    static func mapAccountType(account: PlaidAccount) -> AccountType? {
        switch account.type {
        case .credit: return .creditCard
        case .investment, .brokerage: return .investment
        case .depository:
            let subtype = account.subtype?.lowercased() ?? ""
            if subtype == "savings" { return .savings }
            return .checking
        case .loan:
            return nil
        case .other:
            return .checking
        }
    }

    // MARK: - Transactions

    static func mapTransaction(
        _ transaction: PlaidTransaction,
        calendar: Calendar = Self.plaidCalendar
    ) -> FinancialTransactionSnapshot? {
        guard let currency = resolvedCurrency(
            iso: transaction.isoCurrencyCode,
            unofficial: transaction.unofficialCurrencyCode
        ) else {
            return nil
        }
        guard let date = parsePlaidDate(transaction.date, calendar: calendar) else {
            return nil
        }

        // Plaid outflow-positive → NomadFi outflow-negative.
        let signed = -transaction.amount

        let merchant: String = {
            if let m = transaction.merchantName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !m.isEmpty {
                return m
            }
            return transaction.name
        }()

        return FinancialTransactionSnapshot(
            id: transaction.transactionID,
            providerKind: .externalAggregator(identifier: providerIdentifier),
            accountID: transaction.accountID,
            merchantName: merchant,
            amount: signed,
            currencyCode: currency,
            date: date,
            category: mapCategory(transaction.personalFinanceCategory?.primary),
            externalTransactionID: transaction.transactionID
        )
    }

    // MARK: - Category mapping

    /// Plaid's personal-finance-category primary → NomadFi category.
    /// Deliberately narrow; unknown primaries fall through to `.other`.
    /// Reference taxonomy:
    /// https://plaid.com/docs/transactions/personal-finance-categories/.
    static func mapCategory(_ primary: String?) -> TransactionCategory {
        guard let raw = primary?.uppercased() else { return .other }
        switch raw {
        case "INCOME": return .income
        case "TRANSFER_IN", "TRANSFER_OUT", "LOAN_PAYMENTS": return .transfer
        case "FOOD_AND_DRINK": return .food
        case "TRANSPORTATION", "TRAVEL": return .transport
        case "RENT_AND_UTILITIES": return .utilities
        case "MEDICAL": return .medical
        case "ENTERTAINMENT": return .entertainment
        case "GENERAL_MERCHANDISE", "PERSONAL_CARE", "HOME_IMPROVEMENT":
            return .shopping
        default: return .other
        }
    }

    // MARK: - Helpers

    /// Stable identifier used on every Plaid-produced snapshot. Kept
    /// constant so `FinancialDataProviderKind.externalAggregator(identifier:)`
    /// round-trips through the persisted `logKey`.
    static let providerIdentifier = "plaid_sandbox"

    static let plaidCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }()

    /// ISO date parser. Plaid `/transactions/sync` returns `YYYY-MM-DD`.
    static func parsePlaidDate(_ raw: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: raw)
    }

    /// Resolves an ISO 4217 currency to NomadFi's `CurrencyCode`. Plaid
    /// sometimes returns `unofficial_currency_code` (crypto / beta);
    /// the mapper prefers the official ISO value and honestly drops
    /// anything NomadFi does not model.
    static func resolvedCurrency(
        iso: String?,
        unofficial: String?
    ) -> CurrencyCode? {
        if let iso,
           let code = CurrencyCode(rawValue: iso.uppercased()) {
            return code
        }
        if let unofficial,
           let code = CurrencyCode(rawValue: unofficial.uppercased()) {
            return code
        }
        return nil
    }
}
