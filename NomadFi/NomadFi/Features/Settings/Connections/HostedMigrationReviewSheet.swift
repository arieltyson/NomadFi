// HostedMigrationReviewSheet.swift
// NomadFi
//
// Reviewing bank records from NomadFi's earlier on-device connection.

import SwiftData
import SwiftUI

/// Shows which older accounts match hosted ones and switches them over
/// only after the person confirms a backup.
struct HostedMigrationReviewSheet: View {

    let review: HostedLegacyMigration
    let banking: HostedBankingController

    @Environment(\.modelContext) private var modelContext
    @State private var backupVerified = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(review.accounts, id: \.localID) { Text($0.label) }
                } header: {
                    Text("Matching accounts")
                } footer: {
                    Text("\(review.transactions.count) transactions will switch to server updates. Notes and receipts are kept.")
                }
                Section {
                    Toggle("I have a current backup of this iPhone", isOn: $backupVerified)
                    Button("Switch to Server Updates") {
                        Task { await banking.confirmLegacyMigration(container: modelContext.container) }
                    }
                    .disabled(!backupVerified || banking.isWorking)
                } footer: {
                    Text("Matches use the bank's unchanged account IDs; names and balances aren't enough.")
                }
            }
            .navigationTitle("Older Bank Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: banking.cancelLegacyMigration)
                }
            }
        }
    }
}
