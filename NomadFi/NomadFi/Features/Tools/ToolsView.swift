// ToolsView.swift
// NomadFi
//
// The Tools tab: NomadFi's optional manual workflows, one tap each.

import SwiftUI

/// The root of the Tools tab.
///
/// Each tool relies on this tab's `NavigationStack` for its own
/// pushes and sheets.
struct ToolsView: View {

    var body: some View {
        List {
            HubNavigationRow("Subscriptions", systemImage: "arrow.triangle.2.circlepath") {
                SubscriptionsView()
            }

            HubNavigationRow("Ledger", systemImage: "list.bullet.rectangle") {
                LedgerView()
            }

            HubNavigationRow("Import Transactions", systemImage: "tablecells.badge.ellipsis") {
                TransactionImportView()
            }

            HubNavigationRow("Tax Vault", systemImage: "doc.text.viewfinder") {
                TaxVaultView()
            }

            HubNavigationRow("Investing Learn", systemImage: "books.vertical") {
                InvestingLearnView()
            }
        }
        .navigationTitle("Tools")
    }
}

#Preview {
    NavigationStack {
        ToolsView()
    }
}
