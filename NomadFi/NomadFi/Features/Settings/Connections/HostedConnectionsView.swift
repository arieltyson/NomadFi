import AuthenticationServices
import SwiftData
import SwiftUI

struct HostedConnectionsView: View {
    @Environment(\.modelContext) private var modelContext
    let banking: HostedBankingController
    @State private var hasConsented = false
    @State private var disconnecting: HostedConnection?

    var body: some View {
        List {
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
                    .disabled(!hasConsented || banking.challenge == nil || banking.isWorking)
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
                } footer: {
                    Text("The server checks for bank updates independently. Opening NomadFi downloads completed updates. Bank data can be delayed; signing out keeps this iPhone's local records.")
                }
            }
            if let message = banking.message {
                Section { Text(message).foregroundStyle(.secondary).accessibilityAddTraits(.updatesFrequently) }
            }
            if banking.isWorking { ProgressView("Updating connections") }
        }
        .navigationTitle("Hosted Connections")
        .disabled(banking.isWorking)
        .task { await banking.prepare() }
        .refreshable { await banking.prepare() }
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
