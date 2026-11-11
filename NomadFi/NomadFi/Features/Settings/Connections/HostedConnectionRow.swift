// HostedConnectionRow.swift
// NomadFi
//
// One linked bank: its name, how it's doing, and its actions.

import SwiftUI

/// A bank row. The name and one status line are all that show; Manage
/// Access and Disconnect live in the row's menu and Disconnect also
/// on swipe. A bank that needs sign-in gets a visible Reconnect button,
/// because that is the one action it can't do without.
struct HostedConnectionRow: View {

    let connection: HostedConnection
    let onManageAccess: () -> Void
    let onDisconnect: () -> Void

    private var status: HostedConnectionStatus { HostedConnectionStatus(rawValue: connection.state) }
    private var name: String { connection.institutionName ?? String(localized: "Bank") }

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(name)
                    .font(.headline)
                HostedConnectionStatusLine(status: status, fetchedAt: connection.lastSyncedDate)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if status == .needsSignIn {
                Button("Reconnect", action: onManageAccess)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            Menu("Options for \(name)", systemImage: "ellipsis.circle") {
                Button("Manage Access", systemImage: "key", action: onManageAccess)
                Button("Disconnect", systemImage: "xmark.circle", role: .destructive, action: onDisconnect)
            }
            .labelStyle(.iconOnly)
        }
        .swipeActions {
            Button("Disconnect", role: .destructive, action: onDisconnect)
        }
    }
}

/// "Connected · Updated 5:07 PM", with the status symbol in its colour.
private struct HostedConnectionStatusLine: View {

    let status: HostedConnectionStatus
    let fetchedAt: Date?

    var body: some View {
        Label {
            if let fetchedAt {
                Text("\(Text(status.title)) · Updated \(HostedTimestamp.text(fetchedAt))")
            } else {
                Text(status.title)
            }
        } icon: {
            Image(systemName: status.systemImage).foregroundStyle(status.tint)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
