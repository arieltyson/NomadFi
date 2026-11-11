// HostedSyncStatusRow.swift
// NomadFi
//
// The one line that says whether this iPhone has the latest bank data.

import SwiftUI

/// Shows the download state and the single action that fits it:
/// Update when idle or current, Try Again after a failure, nothing
/// while downloading. A download the person asked for ends with a haptic
/// and a VoiceOver announcement; automatic refreshes end silently.
struct HostedSyncStatusRow: View {

    let state: HostedSyncState
    /// Finished downloads the person asked for. Feedback is tied to this,
    /// not to `state`, so automatic refreshes stay silent.
    let userOutcomes: Int
    let onUpdate: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            HostedSyncStatusLabel(state: state)
                .frame(maxWidth: .infinity, alignment: .leading)
            switch state {
            case .syncing:
                EmptyView()
            case .failed:
                Button("Try Again", action: onUpdate)
                    .buttonStyle(.borderedProminent)
            case .idle, .upToDate:
                Button("Update", action: onUpdate)
                    .buttonStyle(.bordered)
            }
        }
        .controlSize(.small)
        .sensoryFeedback(trigger: userOutcomes) { _, _ in
            switch state {
            case .upToDate: .success
            case .failed: .error
            case .idle, .syncing: nil
            }
        }
        .onChange(of: userOutcomes) { _, _ in announce(state) }
    }

    private func announce(_ state: HostedSyncState) {
        let text: String? = switch state {
        case .upToDate: String(localized: "Bank data is up to date.")
        case .failed(let message): message
        case .idle, .syncing: nil
        }
        if let text { AccessibilityNotification.Announcement(text).post() }
    }
}

/// The symbol, headline and detail for each download state.
private struct HostedSyncStatusLabel: View {

    let state: HostedSyncState

    var body: some View {
        switch state {
        case .syncing:
            HStack(spacing: SpacingTokens.xSmall) {
                ProgressView()
                Text("Downloading updates…")
            }
            .accessibilityElement(children: .combine)
        case .upToDate(let date):
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxSmall) {
                    Text("Up to date")
                    Text("Updated \(HostedTimestamp.text(date))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(ColorTokens.positive)
            }
            .accessibilityElement(children: .combine)
        case .failed(let message):
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ColorTokens.warning)
            }
        case .idle:
            Label {
                Text("Bank updates")
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    List {
        HostedSyncStatusRow(state: .idle, userOutcomes: 0) {}
        HostedSyncStatusRow(state: .syncing, userOutcomes: 0) {}
        HostedSyncStatusRow(state: .upToDate(.now), userOutcomes: 0) {}
        HostedSyncStatusRow(state: .failed("Too many requests. Try again in a minute."), userOutcomes: 0) {}
    }
}
