// MockFinanceDataService.swift
// NomadFi
//
// Mock implementation of FinanceDataService for SwiftUI Previews
// and unit testing. Returns sample international student financial data.

import Foundation

/// A mock finance data service returning sample data for the TT -> CA -> US corridor.
///
/// Provides realistic sample accounts and transactions that demonstrate
/// NomadFi's cross-border features in Previews and tests.
struct MockFinanceDataService: FinanceDataService {

    var authorizationStatus: FinanceDataAuthorizationStatus = .authorized
    var simulatedDelay: Duration = .milliseconds(200)
    var shouldFail: Bool = false

    func checkAuthorization() async -> FinanceDataAuthorizationStatus {
        authorizationStatus
    }

    func requestAuthorization() async throws -> FinanceDataAuthorizationStatus {
        try await Task.sleep(for: simulatedDelay)
        return authorizationStatus
    }

    func fetchAccounts() async throws -> [AccountSnapshot] {
        try await Task.sleep(for: simulatedDelay)

        if shouldFail {
            throw FinanceDataServiceError.connectionFailed
        }

        return Self.sampleAccounts
    }

    func fetchTransactions(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [TransactionSnapshot] {
        try await Task.sleep(for: simulatedDelay)

        if shouldFail {
            throw FinanceDataServiceError.connectionFailed
        }

        return Self.sampleTransactions.filter { $0.date >= startDate && $0.date <= endDate }
    }

    // MARK: - Sample Data

    static let sampleAccounts: [AccountSnapshot] = [
        AccountSnapshot(
            id: "chase-freedom",
            name: "Freedom Rise",
            institutionName: "Chase",
            balance: 2_340.50,
            currencyCode: .usd,
            accountType: .creditCard
        ),
        AccountSnapshot(
            id: "chase-checking",
            name: "Total Checking",
            institutionName: "Chase",
            balance: 4_125.00,
            currencyCode: .usd,
            accountType: .checking
        ),
        AccountSnapshot(
            id: "cibc-chequing",
            name: "Smart Chequing",
            institutionName: "CIBC",
            balance: 8_750.25,
            currencyCode: .cad,
            accountType: .checking
        ),
        AccountSnapshot(
            id: "rbc-savings",
            name: "High Interest Savings",
            institutionName: "RBC",
            balance: 15_320.00,
            currencyCode: .cad,
            accountType: .savings
        ),
        AccountSnapshot(
            id: "fcb-savings",
            name: "Premium Savings",
            institutionName: "First Citizens",
            balance: 45_000.00,
            currencyCode: .ttd,
            accountType: .savings
        ),
    ]

    static let sampleTransactions: [TransactionSnapshot] = [
        TransactionSnapshot(
            id: "txn-001",
            merchantName: "Whole Foods Market",
            amount: -67.43,
            currencyCode: .usd,
            date: .now.addingTimeInterval(-86400),
            category: .food
        ),
        TransactionSnapshot(
            id: "txn-002",
            merchantName: "BART",
            amount: -5.50,
            currencyCode: .usd,
            date: .now.addingTimeInterval(-86400 * 2),
            category: .transport
        ),
        TransactionSnapshot(
            id: "txn-003",
            merchantName: "Tim Hortons",
            amount: -8.95,
            currencyCode: .cad,
            date: .now.addingTimeInterval(-86400 * 3),
            category: .food
        ),
        TransactionSnapshot(
            id: "txn-004",
            merchantName: "University of Toronto",
            amount: -6_250.00,
            currencyCode: .cad,
            date: .now.addingTimeInterval(-86400 * 10),
            category: .education
        ),
        TransactionSnapshot(
            id: "txn-005",
            merchantName: "Massy Stores",
            amount: -350.00,
            currencyCode: .ttd,
            date: .now.addingTimeInterval(-86400 * 15),
            category: .shopping
        ),
    ]
}

/// Errors that can occur during finance data operations.
enum FinanceDataServiceError: Error, LocalizedError, Sendable {
    case connectionFailed
    case authorizationDenied
    case dataUnavailable

    var errorDescription: String? {
        switch self {
        case .connectionFailed: "Unable to connect to your financial data. Please try again."
        case .authorizationDenied: "NomadFi needs permission to access your financial data."
        case .dataUnavailable: "Financial data is not available on this device."
        }
    }
}
