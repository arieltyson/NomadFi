// JurisdictionSummaryTests.swift
// NomadFi
//
// Pins the Dashboard's country cards: alphabetical order, one card per
// jurisdiction, and each total in local currency.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct JurisdictionSummaryTests {

    @Test("Country cards are alphabetical by name, whatever the profile order")
    func summariesAreAlphabetical() {
        let summaries = DashboardViewModel().jurisdictionSummaries(
            accounts: [],
            jurisdictions: [
                profile("US", "United States", displayOrder: 0),
                profile("TT", "Trinidad and Tobago", displayOrder: 1),
                profile("CA", "Canada", displayOrder: 2),
            ]
        )

        #expect(summaries.map(\.profile.countryName) == ["Canada", "Trinidad and Tobago", "United States"])
    }

    @Test("Each card totals only its own accounts; a country without accounts still has a card")
    func summariesTotalTheirOwnAccounts() {
        let summaries = DashboardViewModel().jurisdictionSummaries(
            accounts: [
                checking(in: "CA", balance: 800),
                checking(in: "CA", balance: 200),
                checking(in: "US", balance: 50),
            ],
            jurisdictions: [
                profile("CA", "Canada"),
                profile("US", "United States"),
                profile("TT", "Trinidad and Tobago"),
            ]
        )

        let totals = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0.total) })
        #expect(totals == ["CA": 1_000, "US": 50, "TT": 0])
        #expect(summaries.first { $0.id == "CA" }?.accounts.count == 2)
    }

    private func profile(_ code: String, _ name: String, displayOrder: Int = 0) -> JurisdictionProfile {
        JurisdictionProfile(
            countryCode: code,
            countryName: name,
            currencyCode: .usd,
            isHome: false,
            displayOrder: displayOrder
        )
    }

    private func checking(in jurisdiction: String, balance: Double) -> Account {
        Account(
            name: "Checking",
            institutionName: "Bank",
            accountType: .checking,
            currencyCode: .usd,
            jurisdiction: jurisdiction,
            currentBalance: balance,
            financialSnapshotUpdatedAt: .now,
            financialSnapshotSource: .userSnapshot
        )
    }
}
