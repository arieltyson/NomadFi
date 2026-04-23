// FinancialConnectionRow.swift
// NomadFi
//
// One Settings-style row on the Financial Connections page. Layout
// matches the rest of the Settings hub: tinted icon badge, title,
// calm status line, last-sync detail when present, and an explicit
// "Authorize" button when the provider can be moved through consent.
//
// No onTapGesture — the button surface is a native `Button` so
// VoiceOver and keyboard navigation behave correctly without extra
// plumbing.

import SwiftUI

struct FinancialConnectionRow: View {

    let row: FinancialConnectionsViewModel.Row
    let isWorking: Bool
    let onAuthorize: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            TintedIconBadge(systemImage: iconName, tint: iconTint)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(row.title)
                    .font(TypographyTokens.body)

                Text(row.statusLabel)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                if let lastSync = row.lastSyncDetail {
                    Text(lastSync)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SpacingTokens.xSmall)

            if row.canRequestAuthorization {
                Button {
                    onAuthorize()
                } label: {
                    Text("Authorize")
                        .font(TypographyTokens.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isWorking)
                .accessibilityHint("Opens the provider's authorization prompt.")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Helpers

private extension FinancialConnectionRow {

    var iconName: String {
        switch row.kind {
        case .manual: "square.and.pencil"
        case .csvImport: "doc.text"
        case .financeKit: "applelogo"
        case .externalAggregator: "link.badge.plus"
        }
    }

    var iconTint: Color {
        switch row.kind {
        case .manual: ColorTokens.brandSecondary
        case .csvImport: ColorTokens.neutral
        case .financeKit: ColorTokens.brandPrimary
        case .externalAggregator: ColorTokens.neutral
        }
    }

    /// Combines the visible title with the status line so VoiceOver
    /// reads it as a single row, matching Apple Settings behaviour.
    var accessibilityDescription: Text {
        if let lastSync = row.lastSyncDetail {
            return Text("\(Text(row.title)). \(Text(row.statusLabel)). \(Text(lastSync))")
        }
        return Text("\(Text(row.title)). \(Text(row.statusLabel))")
    }
}
