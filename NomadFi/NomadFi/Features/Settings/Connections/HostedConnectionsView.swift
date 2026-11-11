// HostedConnectionsView.swift
// NomadFi
//
// Bank Connections: sign in once, see whether this iPhone is current,
// and manage each linked bank.

import SwiftData
import SwiftUI

/// The hosted bank connections screen.
///
/// Signed in, it reads top to bottom as status, banks, then sign out:
/// one line saying whether this iPhone has the latest bank data, the
/// banks with their own status, and a quiet footer for where data is
/// kept. Actions that only sometimes apply (finishing an interrupted
/// link, reviewing older records) appear only when they do. Opening
/// the screen downloads updates on its own; pull to refresh does too.
struct HostedConnectionsView: View {

    @Environment(\.modelContext) private var modelContext
    let banking: HostedBankingController

    @State private var hasConsented = false
    @State private var disconnecting: HostedConnection?

    var body: some View {
        List {
            if let message = banking.message {
                Section {
                    Label(message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }

            #if DEBUG
            if let subject = banking.refusedAppleSubject {
                HostedPilotAccessSection(subject: subject)
            }
            #endif

            if banking.userID == nil {
                HostedSignInSection(banking: banking, hasConsented: $hasConsented)
            } else {
                Section {
                    HostedSyncStatusRow(state: banking.syncState) {
                        Task { await banking.sync(container: modelContext.container) }
                    }
                }

                Section {
                    ForEach(banking.connections) { connection in
                        HostedConnectionRow(
                            connection: connection,
                            onManageAccess: { Task { await banking.startLink(connectionID: connection.id) } },
                            onDisconnect: { disconnecting = connection }
                        )
                    }
                    Button("Connect a Bank", systemImage: "plus") {
                        Task { await banking.startLink() }
                    }
                    .disabled(banking.isWorking)
                    if banking.hasPendingExchange {
                        Button("Finish Connecting", systemImage: "arrow.clockwise") {
                            Task { await banking.retryExchange() }
                        }
                        .disabled(banking.isWorking)
                    }
                } header: {
                    Text("Banks")
                } footer: {
                    HostedDataFooter(
                        region: banking.hostingRegion,
                        backupRetentionDays: banking.backupRetentionDays,
                        privacyPolicyURL: banking.privacyPolicyURL
                    )
                }

                if banking.hasLegacyRecords {
                    Section {
                        Button("Review Older Bank Records") {
                            Task { await banking.prepareLegacyMigration(container: modelContext.container) }
                        }
                        .disabled(banking.isWorking)
                    } footer: {
                        Text("Records from NomadFi's earlier bank connection need a review before new updates can be saved.")
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await banking.signOut() }
                    }
                    .disabled(banking.isWorking)
                }
            }
        }
        .navigationTitle("Bank Connections")
        .task { await refresh() }
        .refreshable { await refresh() }
        .sheet(item: Binding(get: { banking.migrationReview }, set: { if $0 == nil { banking.cancelLegacyMigration() } })) { review in
            HostedMigrationReviewSheet(review: review, banking: banking)
        }
        .alert(
            "Disconnect \(disconnecting?.institutionName ?? String(localized: "this bank"))?",
            isPresented: Binding(get: { disconnecting != nil }, set: { if !$0 { disconnecting = nil } })
        ) {
            Button("Cancel", role: .cancel) { disconnecting = nil }
            Button("Disconnect", role: .destructive) {
                guard let connection = disconnecting else { return }
                disconnecting = nil
                Task { await banking.disconnect(connection.id) }
            }
        } message: {
            Text("New updates stop and bank access is revoked. History already on this iPhone stays.")
        }
    }

    /// Signs in state, then downloads whatever the server has finished.
    private func refresh() async {
        await banking.prepare()
        banking.refreshLocalState(container: modelContext.container)
        await banking.sync(container: modelContext.container)
    }
}
