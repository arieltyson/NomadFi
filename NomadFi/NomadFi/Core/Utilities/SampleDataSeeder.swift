// SampleDataSeeder.swift
// NomadFi
//
// Seeds the database with realistic sample data for the first-run
// demo experience. Shows international students what the app looks
// like with real data before they add their own accounts.

import Foundation
import OSLog
import SwiftData

/// Seeds realistic sample data for the first-run experience.
///
/// Populates the dashboard with representative accounts and transactions
/// from the TT → CA → US corridor so new users immediately understand
/// the value of cross-border financial visibility. All sample data is
/// removed when the user adds their own real accounts.
enum SampleDataSeeder {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "SampleData")

    // MARK: - Public API

    /// Seeds sample data if no accounts exist yet.
    ///
    /// Call on first dashboard appearance after onboarding. Safe to call
    /// multiple times — exits immediately if real data is present.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        logger.info("No accounts found — seeding sample data for first-run experience")

        seedSampleJurisdictions(modelContext: modelContext)
        seedSampleAccounts(modelContext: modelContext)
        seedSampleTransactions(modelContext: modelContext)
    }

    /// Removes all sample data.
    ///
    /// Called when the user adds their first real account so sample
    /// records don't pollute their financial picture.
    @MainActor
    static func removeSampleData(modelContext: ModelContext) {
        try? modelContext.delete(model: Transaction.self)
        try? modelContext.delete(model: Account.self)
        logger.info("Sample data removed")
    }

    // MARK: - Private Seeding

    @MainActor
    private static func seedSampleJurisdictions(modelContext: ModelContext) {
        let jurisdictions = [
            JurisdictionProfile(
                countryCode: "TT",
                countryName: "Trinidad & Tobago",
                currencyCode: .ttd,
                isHome: true,
                displayOrder: 0
            ),
            JurisdictionProfile(
                countryCode: "CA",
                countryName: "Canada",
                currencyCode: .cad,
                isHome: false,
                displayOrder: 1
            ),
            JurisdictionProfile(
                countryCode: "US",
                countryName: "United States",
                currencyCode: .usd,
                isHome: false,
                displayOrder: 2
            ),
        ]

        for jurisdiction in jurisdictions {
            modelContext.insert(jurisdiction)
        }
    }

    @MainActor
    private static func seedSampleAccounts(modelContext: ModelContext) {
        // Sample accounts illustrate the snapshot model:
        //   * Deposit accounts carry a timestamped current-balance
        //     snapshot instead of the legacy flat `balance`.
        //   * Credit cards carry a credit limit (capacity, not an
        //     asset) alongside a snapshot of current balance and
        //     available credit.
        // No real personal balances are hardcoded here — all numbers
        // are illustrative.
        let accounts = [
            Account(
                name: "Republic Bank Savings",
                institutionName: "Republic Bank",
                accountType: .savings,
                currencyCode: .ttd,
                jurisdiction: "TT",
                currentBalance: 45_000.00,
                financialSnapshotUpdatedAt: .now,
                financialSnapshotSource: .userSnapshot
            ),
            Account(
                name: "CIBC Chequing",
                institutionName: "CIBC",
                accountType: .checking,
                currencyCode: .cad,
                jurisdiction: "CA",
                foreignTransactionFeePercent: 2.5,
                currentBalance: 3_250.75,
                financialSnapshotUpdatedAt: .now,
                financialSnapshotSource: .userSnapshot
            ),
            Account(
                name: "Chase Freedom Rise",
                institutionName: "JPMorgan Chase",
                accountType: .creditCard,
                currencyCode: .usd,
                jurisdiction: "US",
                foreignTransactionFeePercent: 0,
                creditLimit: 500,
                currentBalance: 125.00,
                availableCredit: 375.00,
                financialSnapshotUpdatedAt: .now,
                financialSnapshotSource: .userSnapshot
            ),
        ]

        for account in accounts {
            modelContext.insert(account)
        }
    }

    @MainActor
    private static func seedSampleTransactions(modelContext: ModelContext) {
        let calendar = Calendar.current

        let transactions = [
            // Recent US grocery purchase — domestic, no FX
            Transaction(
                merchantName: "Whole Foods Market",
                originalAmount: -67.43,
                originalCurrency: .usd,
                convertedAmount: -67.43,
                homeCurrency: .usd,
                date: calendar.date(byAdding: .day, value: -1, to: .now) ?? .now,
                category: .food,
                jurisdiction: "US"
            ),

            // Cross-border: CAD purchase with US card (FX markup)
            Transaction(
                merchantName: "Tim Hortons",
                originalAmount: -8.50,
                originalCurrency: .cad,
                convertedAmount: -6.25,
                homeCurrency: .usd,
                appliedExchangeRate: 0.7353,
                midMarketRate: 0.7200,
                date: calendar.date(byAdding: .day, value: -2, to: .now) ?? .now,
                category: .food,
                jurisdiction: "CA"
            ),

            // Tuition payment — large, tax-relevant
            Transaction(
                merchantName: "University Tuition",
                originalAmount: -4_500.00,
                originalCurrency: .usd,
                convertedAmount: -4_500.00,
                homeCurrency: .usd,
                date: calendar.date(byAdding: .day, value: -5, to: .now) ?? .now,
                category: .education,
                jurisdiction: "US",
                isTaxDeductible: true
            ),

            // Transit in Canada
            Transaction(
                merchantName: "TTC Monthly Pass",
                originalAmount: -156.00,
                originalCurrency: .cad,
                convertedAmount: -112.32,
                homeCurrency: .usd,
                appliedExchangeRate: 0.72,
                midMarketRate: 0.72,
                date: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now,
                category: .transport,
                jurisdiction: "CA"
            ),

            // Entertainment — streaming subscription
            Transaction(
                merchantName: "Netflix",
                originalAmount: -16.99,
                originalCurrency: .cad,
                convertedAmount: -12.23,
                homeCurrency: .usd,
                appliedExchangeRate: 0.72,
                midMarketRate: 0.72,
                date: calendar.date(byAdding: .day, value: -7, to: .now) ?? .now,
                category: .entertainment,
                jurisdiction: "CA"
            ),

            // Remittance to TT
            Transaction(
                merchantName: "Wise Transfer Home",
                originalAmount: -200.00,
                originalCurrency: .usd,
                convertedAmount: -1_354.00,
                homeCurrency: .ttd,
                appliedExchangeRate: 6.77,
                midMarketRate: 6.75,
                date: calendar.date(byAdding: .day, value: -10, to: .now) ?? .now,
                category: .other,
                jurisdiction: "TT"
            ),
        ]

        for transaction in transactions {
            modelContext.insert(transaction)
        }
    }
}
