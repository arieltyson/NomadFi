// AdvancedToolsSettingsView.swift
// NomadFi
//
// Home for Subscriptions, Ledger, and Tax Vault once they stopped
// being primary tabs. Keeps the hub's top-level list short while the
// tools remain a single tap away for users who want the manual
// workflows. Subscriptions lives here because cross-border
// subscription arbitrage is a companion to the Decision Assistant —
// valuable context, but not a daily-driver surface until automatic
// detection and stronger scenarios exist.

import SwiftUI

struct AdvancedToolsSettingsView: View {

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SubscriptionsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                            Text("Subscriptions")
                                .font(TypographyTokens.body)
                            Text("Recurring-charge detection and cross-border pricing review.")
                                .font(TypographyTokens.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                .accessibilityHint("Opens the subscription tracker and savings comparison.")

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
                    TransactionImportView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                            Text("Transaction Import")
                                .font(TypographyTokens.body)
                            Text("Parse and preview a CSV statement locally before writing anything.")
                                .font(TypographyTokens.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "tablecells.badge.ellipsis")
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                .accessibilityHint("Opens the CSV import preview flow. No data leaves this device.")

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

                NavigationLink {
                    InvestingLearnView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                            Text("Investing Learn")
                                .font(TypographyTokens.body)
                            Text("Source-backed investing literacy starter for your jurisdictions.")
                                .font(TypographyTokens.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "books.vertical")
                            .foregroundStyle(ColorTokens.brandPrimary)
                    }
                }
                .accessibilityHint("Opens short, source-backed investing lessons. Education only — not investment advice.")
            } footer: {
                Text("Optional companions. NomadFi's primary recommendations come from the Decision Assistant — these tools stay here for users who want deeper manual tracking.")
            }
        }
        .navigationTitle("Advanced Tools")
    }
}
