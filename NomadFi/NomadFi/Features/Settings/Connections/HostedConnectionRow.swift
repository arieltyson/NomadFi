// HostedConnectionRow.swift
// NomadFi
//
// One linked bank: its name, how it's doing, and its actions.

import SwiftUI

/// A bank row: a status symbol, then the name over one status line.
/// Manage Access and Disconnect live in the row's menu and Disconnect
/// also on swipe. A bank that needs sign-in gets a visible Reconnect
/// button, because that is the one action it can't do without. Until the
/// server's first fetch lands, the row shows progress rather than a check.
struct HostedConnectionRow: View {

    let connection: HostedConnection
    let onManageAccess: () -> Void
    let onDisconnect: () -> Void

    private var status: HostedConnectionStatus { HostedConnectionStatus(rawValue: connection.state) }
    private var name: String { connection.institutionName ?? String(localized: "Your bank") }

    /// Linked, but the server's first fetch from the bank hasn't landed.
    private var isAwaitingFirstSync: Bool { status == .connected && connection.lastSyncedDate == nil }

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            HostedConnectionStatusSymbol(status: status, isAwaitingFirstSync: isAwaitingFirstSync)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(name)
                    .font(.headline)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        .accessibilityElement(children: .contain)
        .swipeActions {
            Button("Disconnect", role: .destructive, action: onDisconnect)
        }
    }

    /// "Connected · Updated 5:07 PM", or what is happening before then.
    private var statusText: String {
        if isAwaitingFirstSync { return String(localized: "Getting your history…") }
        let title = String(localized: status.title)
        guard let fetchedAt = connection.lastSyncedDate else { return title }
        return String(localized: "\(title) · Updated \(HostedTimestamp.text(fetchedAt))")
    }
}

/// The row's leading symbol: a spinner until the first sync lands, then
/// the status symbol in its colour.
private struct HostedConnectionStatusSymbol: View {

    let status: HostedConnectionStatus
    let isAwaitingFirstSync: Bool

    var body: some View {
        Group {
            if isAwaitingFirstSync {
                ProgressView()
            } else {
                Image(systemName: status.systemImage)
                    .font(.title3)
                    .foregroundStyle(status.tint)
            }
        }
        .accessibilityHidden(true)
    }
}
