// TaxDocumentOrganizationPromptSection.swift
// NomadFi
//
// "Organize your records" section rendered inside the Tax Vault
// Learn surface, just below the recognition strip and above the
// region education blocks. Hides itself when the deterministic
// `TaxDocumentOrganizationPromptService` returns an empty list.

import SwiftUI

struct TaxDocumentOrganizationPromptSection: View {

    let prompts: [TaxDocumentOrganizationPrompt]

    /// Forwarded to each card so the parent can flip
    /// `TaxVaultView.surface` when the user taps a primary action.
    let onSelectTarget: (TaxDocumentOrganizationPromptTarget) -> Void

    var body: some View {
        if !prompts.isEmpty {
            Section {
                ForEach(prompts) { prompt in
                    TaxDocumentOrganizationPromptCard(
                        prompt: prompt,
                        onSelectTarget: onSelectTarget
                    )
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Label("Organize your records", systemImage: "tray.full")
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(prompts.count)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                Text("Education only. Not a substitute for a qualified professional. NomadFi does not file on your behalf.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
