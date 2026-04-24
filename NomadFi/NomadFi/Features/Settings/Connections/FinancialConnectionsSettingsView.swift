// FinancialConnectionsSettingsView.swift
// NomadFi
//
// Settings → Financial Setup → Financial Connections detail page.
// Renders one row per registered ``FinancialDataProvider``, an
// explicit Sync Now action, and the last reconciliation summary.
//
// Apple-Settings-style layout (List + Section + footer text) rather
// than a dashboard card surface. Copy is calm and factual: the page
// never implies universal coverage or claims a non-Apple aggregator
// is connected.

import SwiftData
import SwiftUI

struct FinancialConnectionsSettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.plaidLinkCoordinator) private var plaidLinkCoordinator

    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @State private var viewModel: FinancialConnectionsViewModel

    init(viewModel: FinancialConnectionsViewModel = FinancialConnectionsViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            providersSection(viewModel: viewModel)
            plaidLinkSection(viewModel: viewModel, plaidLink: plaidLinkCoordinator)
            syncSection(viewModel: viewModel)
            privacySection
        }
        .navigationTitle("Financial Connections")
        .glassToolbar()
        .task {
            await viewModel.refresh()
        }
        .onChange(of: plaidLinkCoordinator.phase) { _, newPhase in
            if case .completed = newPhase {
                Task { await viewModel.refreshAfterPlaidLink() }
            }
        }
    }
}

// MARK: - Sections

private extension FinancialConnectionsSettingsView {

    func providersSection(viewModel: FinancialConnectionsViewModel) -> some View {
        Section {
            ForEach(viewModel.rows) { row in
                FinancialConnectionRow(
                    row: row,
                    isWorking: viewModel.isWorking
                ) {
                    Task { await viewModel.requestAuthorization(for: row.kind) }
                }
            }
        } header: {
            Text("Data Sources")
        } footer: {
            Text("Manual entry and CSV import stay available even when other sources are not. Apple FinanceKit is on-device and entitlement-gated; external aggregators are not enabled in this build.")
        }
    }

    /// Renders the bounded Plaid *sandbox* Link launch only when the
    /// provider row is visible and the broker URL is configured in
    /// the Keychain. Hidden in production / un-configured builds so
    /// the page stays honest about coverage.
    @ViewBuilder
    func plaidLinkSection(
        viewModel: FinancialConnectionsViewModel,
        plaidLink: PlaidLinkCoordinator
    ) -> some View {
        let kind = FinancialDataProviderKind.externalAggregator(
            identifier: PlaidSandboxSnapshotMapper.providerIdentifier
        )
        if let plaidRow = viewModel.rows.first(where: { $0.kind == kind }),
           plaidRow.availability.isAvailable {
            Section {
                Button {
                    Task { await plaidLink.startRealLinkFlow() }
                } label: {
                    Label("Link a sandbox bank with Plaid Link", systemImage: "link")
                }
                .disabled(plaidLink.phase.isBusy)
                .accessibilityHint("Opens Plaid Link against the locally-configured sandbox broker.")

                Text(plaidLink.phase.statusLabel)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Plaid sandbox Link")
            } footer: {
                Text("This button only works when the local Plaid sandbox broker is running. It is a developer-only path for NomadFi's Phase 5D proof, not a production connection flow.")
            }
        }
    }

    func syncSection(viewModel: FinancialConnectionsViewModel) -> some View {
        Section {
            Button {
                Task { await runSync(viewModel: viewModel) }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(viewModel.isWorking)
            .accessibilityHint("Runs a sync across every available provider and reconciles the result into your accounts.")

            if let summary = viewModel.lastSyncSummary {
                Text(summary)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Sync")
        } footer: {
            Text("NomadFi only syncs in response to this action. Nothing runs in the background yet.")
        }
    }

    var privacySection: some View {
        Section {
            EmptyView()
        } footer: {
            Text("FinanceKit data stays on-device and is never seen by Apple. NomadFi does not ship a third-party aggregator SDK in this build.")
        }
    }
}

// MARK: - Helpers

private extension FinancialConnectionsSettingsView {

    func runSync(viewModel: FinancialConnectionsViewModel) async {
        let (start, end) = defaultSyncWindow()
        await viewModel.syncNow(
            from: start,
            to: end,
            modelContext: modelContext,
            existingAccounts: accounts,
            existingTransactions: transactions
        )
    }

    /// Default 90-day window. The Financial Connections page is for
    /// steady-state refresh; a narrower window avoids pulling years
    /// of history on every tap.
    func defaultSyncWindow() -> (Date, Date) {
        let now = Date.now
        let start = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -90, to: now) ?? now
        return (start, now)
    }
}

#Preview {
    NavigationStack {
        FinancialConnectionsSettingsView(
            viewModel: FinancialConnectionsViewModel(
                coordinator: .preview(),
                homeCurrency: .usd
            )
        )
    }
    .modelContainer(for: [
        JurisdictionProfile.self,
        Account.self,
        Transaction.self,
        Subscription.self,
        TaxDocument.self,
        Budget.self,
        ExchangeRate.self,
    ], inMemory: true)
}
