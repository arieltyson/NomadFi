// FinanceDataService.swift
// NomadFi
//
// Protocol defining financial data access operations.
// Abstracts over FinanceKit for real data and mock data for testing.

import Foundation

/// Defines the contract for accessing financial account and transaction data.
///
/// The live implementation wraps Apple's FinanceKit; the mock
/// provides sample data for Previews and unit tests.
protocol FinanceDataService: Sendable {

    /// Checks whether the user has authorized access to financial data.
    func checkAuthorization() async -> FinanceDataAuthorizationStatus

    /// Requests authorization to access the user's financial data.
    func requestAuthorization() async throws -> FinanceDataAuthorizationStatus

    /// Fetches all available accounts from the financial data source.
    func fetchAccounts() async throws -> [AccountSnapshot]

    /// Fetches transactions for a given account within a date range.
    /// - Parameters:
    ///   - accountID: The identifier of the account.
    ///   - startDate: The beginning of the date range.
    ///   - endDate: The end of the date range.
    func fetchTransactions(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [TransactionSnapshot]
}

/// The authorization state for financial data access.
enum FinanceDataAuthorizationStatus: Sendable {
    case authorized
    case denied
    case notDetermined
    case unavailable
}

/// A lightweight snapshot of an account from FinanceKit or manual entry.
struct AccountSnapshot: Sendable, Identifiable {
    let id: String
    let name: String
    let institutionName: String
    let balance: Double
    let currencyCode: CurrencyCode
    let accountType: AccountType
}

/// A lightweight snapshot of a transaction from FinanceKit or manual entry.
struct TransactionSnapshot: Sendable, Identifiable {
    let id: String
    let merchantName: String
    let amount: Double
    let currencyCode: CurrencyCode
    let date: Date
    let category: TransactionCategory
}
