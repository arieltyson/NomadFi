// FinancialSetupSettingsView.swift
// NomadFi
//
// Settings → Financial Setup: a short hub. Each list that grows with
// the person's data — accounts, jurisdictions, credit cards — lives on
// a page of its own, so this one never takes long to scan.

import SwiftData
import SwiftUI

struct FinancialSetupSettingsView: View {

    @Query private var accounts: [Account]
    @Query private var jurisdictions: [JurisdictionProfile]

    var body: some View {
        List {
            HubNavigationRow(
                "Accounts",
                systemImage: "creditcard.fill",
                tint: ColorTokens.brandPrimary,
                value: "\(accounts.count)"
            ) {
                AccountListView()
            }

            HubNavigationRow(
                "Jurisdictions",
                systemImage: "globe.americas.fill",
                tint: .blue,
                value: "\(jurisdictions.count)"
            ) {
                JurisdictionManagementView()
            }

            HubNavigationRow(
                "Credit Card Calendar",
                systemImage: "calendar",
                tint: .orange
            ) {
                CreditCardCalendarView()
            }

            HubNavigationRow(
                "Financial Connections",
                systemImage: "link",
                tint: .indigo
            ) {
                FinancialConnectionsSettingsView()
            }
        }
        .navigationTitle("Financial Setup")
    }
}

#Preview {
    NavigationStack {
        FinancialSetupSettingsView()
    }
    .modelContainer(for: [Account.self, JurisdictionProfile.self], inMemory: true)
}
