// LedgerEmptyStateView.swift
// NomadFi
//
// What the Ledger shows before it holds any transactions.

import SwiftUI

/// A quiet empty state. Adding a transaction is the toolbar's +, so the
/// empty state only explains; a second Add button would offer the same
/// action twice on one screen.
struct LedgerEmptyStateView: View {

    var body: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Transactions from your banks appear here. To add one yourself, tap +.")
        }
    }
}

#Preview {
    LedgerEmptyStateView()
}
