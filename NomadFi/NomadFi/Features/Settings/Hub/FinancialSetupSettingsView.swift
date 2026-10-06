// FinancialSetupSettingsView.swift
// NomadFi
//
// Owns the "Financial Setup" detail page: jurisdictions (with a
// management entry point), accounts (with add/edit flow), and the
// credit-card calendar. Extracted out of `SettingsView` so the hub
// stays short and this page can focus on configuration of the
// account graph.

import SwiftData
import SwiftUI

struct FinancialSetupSettingsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query private var accounts: [Account]

    @State private var isShowingAddAccountSheet = false
    @State private var accountsPendingDeletion: [Account] = []
    @State private var isConfirmingAccountDeletion = false

    var body: some View {
        List {
            jurisdictionsSection

            accountsSection

            connectionsSection

            CreditCardCalendarSection(accounts: accounts)
        }
        .navigationTitle("Financial Setup")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .confirmationDialog("Delete accounts?", isPresented: $isConfirmingAccountDeletion, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for account in accountsPendingDeletion {
                    modelContext.delete(account)
                }
                accountsPendingDeletion = []
            }
            Button("Cancel", role: .cancel) {
                accountsPendingDeletion = []
            }
        } message: {
            Text("Deleting \(accountsPendingDeletion.map(\.name).joined(separator: ", ")) permanently removes its linked transactions, subscriptions, and transaction documents from NomadFi. This cannot be undone.")
        }
        .sheet(isPresented: $isShowingAddAccountSheet) {
            SettingsAddAccountSheet(jurisdictions: jurisdictions) { draft in
                saveAccount(from: draft)
            }
        }
    }
}

// MARK: - Sections

private extension FinancialSetupSettingsView {

    var jurisdictionsSection: some View {
        Section {
            ForEach(jurisdictions) { jurisdiction in
                JurisdictionSettingsRow(jurisdiction: jurisdiction)
            }

            NavigationLink {
                JurisdictionManagementView()
            } label: {
                Label("Manage Jurisdictions", systemImage: "globe.badge.chevron.backward")
            }
            .accessibilityHint("Opens a screen to add, remove, or change your home jurisdiction.")
        } header: {
            Text("Your Jurisdictions")
        } footer: {
            Text("Removing a jurisdiction never deletes its accounts or transactions.")
        }
        .accessibilityLabel("Jurisdictions section")
    }

    var connectionsSection: some View {
        Section {
            NavigationLink {
                FinancialConnectionsSettingsView()
            } label: {
                Label("Financial Connections", systemImage: "link.badge.plus")
            }
            .accessibilityHint("Opens the Financial Connections page where you can see which data sources are available and run an explicit sync.")
        } header: {
            Text("Connections")
        }
    }

    var accountsSection: some View {
        Section {
            if accounts.isEmpty {
                ContentUnavailableView {
                    Label("No Accounts Yet", systemImage: "creditcard")
                } description: {
                    Text("Add your first account to power Dashboard insights and Active Card recommendations.")
                }
            } else {
                ForEach(sortedAccounts) { account in
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        SettingsAccountRow(account: account)
                    }
                    .accessibilityHint("Opens the account editor to correct balances, limits, and other details.")
                }
                .onDelete(perform: deleteAccounts)
            }

            Button("Add Account", systemImage: "plus") {
                isShowingAddAccountSheet = true
            }
            .accessibilityHint("Opens a form to add a new bank account or card.")
        } header: {
            Text("Accounts")
        }
    }
}

// MARK: - Helpers

private extension FinancialSetupSettingsView {

    var sortedAccounts: [Account] {
        accounts.sorted { lhs, rhs in
            if lhs.institutionName == rhs.institutionName {
                return lhs.name < rhs.name
            }
            return lhs.institutionName < rhs.institutionName
        }
    }

    func saveAccount(from draft: SettingsAccountDraft) {
        let snapshotTimestamp: Date? = draft.hasSnapshotValue ? .now : nil
        let snapshotSource: FinancialSnapshotSource? = draft.hasSnapshotValue ? .userSnapshot : nil

        let account = Account(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionName: draft.institutionName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountType: draft.accountType,
            currencyCode: draft.currencyCode,
            jurisdiction: draft.jurisdictionCode,
            foreignTransactionFeePercent: draft.parsedForeignTransactionFeePercent,
            creditLimit: draft.accountType.isCreditCard ? draft.parsedCreditLimit : nil,
            currentBalance: draft.parsedCurrentBalance,
            availableCredit: draft.accountType.isCreditCard ? draft.parsedAvailableCredit : nil,
            financialSnapshotUpdatedAt: snapshotTimestamp,
            financialSnapshotSource: snapshotSource
        )

        modelContext.insert(account)
    }

    func deleteAccounts(at offsets: IndexSet) {
        accountsPendingDeletion = offsets.sorted().map { sortedAccounts[$0] }
        isConfirmingAccountDeletion = !accountsPendingDeletion.isEmpty
    }
}

// MARK: - Jurisdiction row

/// Displays a jurisdiction with its flag, name, currency, and home
/// indicator. Lifted from the old `SettingsView` so the Financial
/// Setup page owns its own row rendering without depending on file
/// order inside `SettingsView`.
struct JurisdictionSettingsRow: View {

    let jurisdiction: JurisdictionProfile

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let increasedContrast = colorSchemeContrast == .increased

        Label {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                HStack(spacing: SpacingTokens.xSmall) {
                    Text(jurisdiction.countryName)
                        .font(TypographyTokens.body)

                    if jurisdiction.isHome {
                        Text("Home")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, SpacingTokens.xxSmall)
                            .padding(.vertical, SpacingTokens.xxxSmall)
                            .background(
                                ColorTokens.tintedFill(ColorTokens.actionTint, contrast: colorSchemeContrast)
                            )
                            .foregroundStyle(ColorTokens.actionTint)
                            .overlay {
                                if increasedContrast {
                                    Capsule()
                                        .strokeBorder(
                                            ColorTokens.increasedContrastOutline,
                                            lineWidth: 1
                                        )
                                }
                            }
                            .clipShape(.capsule)
                    }
                }

                if let currency = jurisdiction.currencyCode {
                    Text("\(currency.rawValue) • \(currency.displayName)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Text(String.flagEmoji(for: jurisdiction.countryCode))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var label = "\(jurisdiction.countryName)"
        if jurisdiction.isHome { label += ", home jurisdiction" }
        if let currency = jurisdiction.currencyCode {
            label += ", currency: \(currency.rawValue), \(currency.displayName)"
        }
        return label
    }
}
