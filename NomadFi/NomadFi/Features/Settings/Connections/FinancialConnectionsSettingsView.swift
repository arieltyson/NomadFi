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
            providersSection
            syncSection
            privacySection
        }
        .navigationTitle("Financial Connections")
        .glassToolbar()
        .task {
            await viewModel.refresh()
        }
    }
}

// MARK: - Sections

private extension FinancialConnectionsSettingsView {

    var providersSection: some View {
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

    var syncSection: some View {
        Section {
            Button {
                Task { await runSync() }
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

    func runSync() async {
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
