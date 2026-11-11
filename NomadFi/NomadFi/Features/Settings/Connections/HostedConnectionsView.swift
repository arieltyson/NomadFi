// HostedConnectionsView.swift
// NomadFi
//
// Bank Connections: an invitation before sign-in, then whether this
// iPhone is current and each linked bank.

import SwiftData
import SwiftUI

/// The hosted bank connections screen.
///
/// Before sign-in it is a single invitation (``HostedSignInView``).
/// Signed in, it reads top to bottom as status, banks, then sign out.
/// Opening the screen keeps data current quietly; pulling to refresh is a
/// request, so it shows progress and gives feedback.
struct HostedConnectionsView: View {

    @Environment(\.modelContext) private var modelContext
    let banking: HostedBankingController

    var body: some View {
        Group {
            if !banking.hasPrepared {
                // The session is still being read; show neither state yet,
                // so a signed-in person never sees the invitation flash by.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if banking.userID == nil {
                HostedSignInView(banking: banking)
            } else {
                HostedBanksList(banking: banking)
            }
        }
        .navigationTitle("Bank Connections")
        .navigationBarTitleDisplayMode(banking.userID == nil ? .inline : .large)
        .task { await banking.refreshAutomatically(container: modelContext.container) }
        .task(id: banking.linkCompletions) {
            guard banking.linkCompletions > 0 else { return }
            await banking.followNewConnection(container: modelContext.container)
        }
        .sheet(item: Binding(get: { banking.migrationReview }, set: { if $0 == nil { banking.cancelLegacyMigration() } })) { review in
            HostedMigrationReviewSheet(review: review, banking: banking)
        }
    }
}

/// The signed-in screen: download status, the banks, then sign out.
/// Actions that only sometimes apply (finishing an interrupted link,
/// reviewing older records) appear only when they do.
private struct HostedBanksList: View {

    let banking: HostedBankingController

    @Environment(\.modelContext) private var modelContext
    @State private var disconnecting: HostedConnection?

    var body: some View {
        List {
            if let message = banking.message {
                Section {
                    Label(message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HostedSyncStatusRow(state: banking.syncState, userOutcomes: banking.userSyncOutcomes) {
                    Task { await banking.sync(container: modelContext.container, trigger: .userInitiated) }
                }
            }

            Section("Banks") {
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
        .refreshable { await refresh() }
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

    /// A refresh the person asked for: reloads banks, then downloads
    /// whatever the server has finished.
    private func refresh() async {
        await banking.prepare()
        await banking.sync(container: modelContext.container, trigger: .userInitiated)
    }
}
