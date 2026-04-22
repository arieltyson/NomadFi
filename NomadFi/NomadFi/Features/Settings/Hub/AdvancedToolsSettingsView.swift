// AdvancedToolsSettingsView.swift
// NomadFi
//
// Home for Ledger and Tax Vault once they stopped being primary tabs.
// Keeps the hub's top-level list short while the tools remain a
// single tap away for users who want the manual workflows.

import SwiftUI

struct AdvancedToolsSettingsView: View {

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LedgerView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                            Text("Ledger")
                                .font(TypographyTokens.body)
                            Text("Manual transaction review and entry.")
                                .font(TypographyTokens.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                .accessibilityHint("Opens the manual transaction ledger.")

                NavigationLink {
                    TaxVaultView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                            Text("Tax Vault")
                                .font(TypographyTokens.body)
                            Text("Receipts and tax documents for later planning.")
                                .font(TypographyTokens.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text.viewfinder")
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                .accessibilityHint("Opens the receipts and tax document archive.")
            } footer: {
                Text("Optional companions. NomadFi's recommendations are built from your accounts and scenarios — you do not need to track every transaction or archive every receipt for the app to work.")
            }
        }
        .navigationTitle("Advanced Tools")
        .glassToolbar()
    }
}
