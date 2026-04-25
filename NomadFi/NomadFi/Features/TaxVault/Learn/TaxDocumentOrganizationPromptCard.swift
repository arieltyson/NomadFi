// TaxDocumentOrganizationPromptCard.swift
// NomadFi
//
// Single calm card rendered for one
// `TaxDocumentOrganizationPrompt`. Layout:
//
//   • SF Symbol + region name (caption)
//   • Title (body, bold, header trait)
//   • Body paragraph
//   • Optional primary action button (Open Review / Open Archive)
//   • Optional source links — external regulator pages
//
// Tapping the primary action calls back through the parent's
// `onSelectTarget` closure so `TaxVaultView` can flip its
// `surface` state. This card never opens a sheet of its own and
// never persists anything.

import SwiftUI

struct TaxDocumentOrganizationPromptCard: View {

    let prompt: TaxDocumentOrganizationPrompt

    /// Called when the user taps the primary action button. Parent
    /// turns this into a `TaxVaultSurface` switch.
    let onSelectTarget: (TaxDocumentOrganizationPromptTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            header
            Text(prompt.body)
                .font(TypographyTokens.body)
                .fixedSize(horizontal: false, vertical: true)
            actionButton
            if !prompt.sources.isEmpty {
                sourcesSection
            }
        }
        .padding(.vertical, SpacingTokens.xxSmall)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                Image(systemName: prompt.region.systemImage)
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
                Text(prompt.region.displayName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
            Text(prompt.title)
                .font(TypographyTokens.body)
                .bold()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Action

    @ViewBuilder
    private var actionButton: some View {
        if let title = prompt.actionTitle, prompt.actionTarget != .none {
            // Always routes through `NomadFiActionButton`, which
            // bakes in `.labelStyle(.titleAndIcon)` so the SF
            // Symbol renders at every control size, every Dynamic
            // Type level, and every press / focus state.
            NomadFiActionButton(
                title: title,
                systemImage: actionSystemImage,
                style: .primary,
                accessibilityHint: accessibilityHint.isEmpty ? nil : accessibilityHint,
                action: { onSelectTarget(prompt.actionTarget) }
            )
        }
    }

    private var actionSystemImage: String {
        switch prompt.actionTarget {
        case .review: "checkmark.circle"
        case .archive: "tray.full"
        case .none: "arrow.right"
        }
    }

    private var accessibilityHint: String {
        switch prompt.actionTarget {
        case .review: "Switches Tax Vault to the Review surface."
        case .archive: "Switches Tax Vault to the Archive surface."
        case .none: ""
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text("Official source")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(prompt.sources) { source in
                Link(destination: source.url) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text(source.title)
                            .font(TypographyTokens.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(source.publisher)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the official source in your browser.")
            }
        }
    }
}
