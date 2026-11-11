import AuthenticationServices
import SwiftData
import SwiftUI

struct HostedConnectionsView: View {
    @Environment(\.modelContext) private var modelContext
    let banking: HostedBankingController
    @State private var hasConsented = false
    @State private var disconnecting: HostedConnection?
    @State private var backupVerified = false

    var body: some View {
        List {
            Section("Hosted data") {
                Text("Hosting region: \(banking.hostingRegion)")
                Group {
                    if banking.backupRetentionDays == 0 {
                        Text("Deleted data isn't kept in backups.")
                    } else {
                        Text("Deleted data may remain in restricted backups for up to \(banking.backupRetentionDays) days.")
                    }
                }
                .font(.footnote)
                if let policyURL = banking.privacyPolicyURL { Link("Hosted privacy policy", destination: policyURL) }
            }
            if banking.userID == nil {
                Section {
                    Toggle("Allow hosted bank synchronization", isOn: $hasConsented)
                    SignInWithAppleButton(.signIn) { request in
                        request.nonce = banking.challenge?.nonce
                        request.requestedScopes = []
                    } onCompletion: { result in
                        Task { await banking.completeAppleSignIn(result) }
                    }
                    .frame(height: 48)
                    .disabled(!hasConsented || banking.challenge == nil || banking.isWorking || banking.privacyPolicyURL == nil)
                } footer: {
                    Text("NomadFi stores your authorized balances and transactions on its hosted service to sync while this iPhone is closed. Plaid handles your bank login. Review the privacy policy before enabling access.")
                }
            } else {
                Section("Banks") {
                    ForEach(banking.connections) { connection in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(connection.institutionName ?? "Linked institution")
                                .font(.headline)
                            Text(status(connection.state)).foregroundStyle(.secondary)
                            if let fetched = connection.lastSyncedAt.flatMap(parseDate) {
                                HStack {
                                    Text("Bank data fetched")
                                    Text(fetched, style: .relative)
                                }.font(.caption)
                            }
                            HStack {
                                Button("Manage access") { Task { await banking.startLink(connectionID: connection.id) } }
                                Spacer()
                                Button("Disconnect", role: .destructive) { disconnecting = connection }
                            }
                        }
                    }
                    Button("Connect another bank", systemImage: "plus") { Task { await banking.startLink() } }
                    Button("Retry finishing connection", systemImage: "arrow.clockwise") { Task { await banking.retryExchange() } }
                }
                Section {
                    Button("Download latest updates", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await banking.sync(container: modelContext.container) }
                    }
                    Button("Sign out") { Task { await banking.signOut() } }
                    Button("Review migration of existing bank records") {
                        backupVerified = false
                        Task { await banking.prepareLegacyMigration(container: modelContext.container) }
                    }
                } footer: {
                    Text("The server checks for bank updates independently. Opening NomadFi downloads completed updates. Bank data can be delayed; signing out keeps this iPhone's local records.")
                }
            }
            #if DEBUG
            if let subject = banking.refusedAppleSubject {
                Section {
                    Text(subject)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    ShareLink("Share Apple ID", item: subject)
                } header: {
                    Text("Pilot access (Debug)")
                } footer: {
                    Text("Add this identifier to the server's APPLE_ALLOWED_SUBJECTS, then sign in again.")
                }
            }
            #endif
            if let message = banking.message {
                Section { Text(message).foregroundStyle(.secondary).accessibilityAddTraits(.updatesFrequently) }
            }
            if banking.isWorking { ProgressView("Updating connections") }
        }
        .navigationTitle("Hosted Connections")
        .disabled(banking.isWorking)
        .task { await banking.prepare() }
        .refreshable { await banking.prepare() }
        .sheet(item: Binding(get: { banking.migrationReview }, set: { if $0 == nil { banking.cancelLegacyMigration() } })) { review in
            NavigationStack {
                Form {
                    Section("Matching existing records") {
                        ForEach(review.accounts, id: \.localID) { Text($0.label) }
                        Text("\(review.transactions.count) imported transactions will be mapped to hosted updates. Notes and receipts are preserved; provider removals use the transaction archive.")
                        Text("Matches use unchanged bank-provider IDs. Newly issued IDs require a separate reviewed map; account names and balances are not enough.").font(.footnote)
                    }
                    Section {
                        Toggle("I verified a current private device backup", isOn: $backupVerified)
                        Button("Use hosted updates for these records") {
                            Task { await banking.confirmLegacyMigration(container: modelContext.container) }
                        }.disabled(!backupVerified || banking.isWorking)
                        Text("This switches local record identities and disables the old local Item handle. It does not revoke the original bank connection. If a rollback is needed, restore the verified backup before re-enabling the local broker.").font(.footnote)
                    }
                }
                .navigationTitle("Review migration")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { banking.cancelLegacyMigration() } } }
            }
        }
        .alert("Disconnect this bank?", isPresented: Binding(get: { disconnecting != nil }, set: { if !$0 { disconnecting = nil } })) {
            Button("Cancel", role: .cancel) { disconnecting = nil }
            Button("Disconnect", role: .destructive) {
                guard let connection = disconnecting else { return }
                disconnecting = nil
                Task { await banking.disconnect(connection.id) }
            }
        } message: {
            Text("Stops new syncs and revokes bank access. Downloaded history and your notes remain on this iPhone.")
        }
    }
    private func status(_ value: String) -> String {
        switch value {
        case "connected": "Connected"
        case "reconnect_required": "Needs authorization"
        case "revoking": "Disconnecting"
        case "disconnected": "Disconnected"
        default: "Status unavailable"
        }
    }
    private func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
