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
#if DEBUG
    @Environment(\.plaidValidationRecorder) private var plaidValidationRecorder
#endif

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
            syncSection(viewModel: viewModel)
#if DEBUG
            // The Plaid sandbox is a developer validation path; release
            // builds neither register its provider nor show its controls.
            plaidLinkSection(viewModel: viewModel, plaidLink: plaidLinkCoordinator)
            developerHarnessSection
#endif
        }
        .navigationTitle("Financial Connections")
        .task {
            await viewModel.refresh()
        }
        .onChange(of: plaidLinkCoordinator.phase) { oldPhase, newPhase in
            if case .completed(let itemID) = newPhase {
                Task { await viewModel.refreshAfterPlaidLink() }
#if DEBUG
                plaidValidationRecorder.recordPublicTokenExchanged(success: true)
                plaidValidationRecorder.recordItemHandlePersisted(rawHandle: itemID)
#endif
            }
#if DEBUG
            // Phase transitions are recorded for every change so the
            // exported artifact captures the full state machine —
            // `fetchingLinkToken → presentingLink → exchangingPublicToken → completed`.
            plaidValidationRecorder.recordLinkPhaseChanged(
                from: Self.label(for: oldPhase),
                to: Self.label(for: newPhase)
            )
            if case .failed(let message) = newPhase {
                plaidValidationRecorder.recordPublicTokenExchanged(
                    success: false,
                    failureReason: message
                )
            }
#endif
        }
    }

#if DEBUG
    /// Stable, redaction-safe label per Plaid Link phase. Used only
    /// by the validation recorder; never surfaced in UI.
    private static func label(for phase: PlaidLinkCoordinator.Phase) -> String {
        switch phase {
        case .idle: return "idle"
        case .fetchingLinkToken: return "fetching_link_token"
        case .presentingLink: return "presenting_link"
        case .exchangingPublicToken: return "exchanging_public_token"
        case .completed: return "completed"
        case .cancelled: return "cancelled"
        case .failed: return "failed"
        }
    }
#endif

#if DEBUG
    /// DEBUG-only entry point into the Plaid sandbox harness page.
    /// Never compiled into Release builds.
    private var developerHarnessSection: some View {
        Section {
            NavigationLink {
                PlaidSandboxDeveloperConfigView()
            } label: {
                Label("Plaid sandbox developer harness", systemImage: "hammer")
            }
            .accessibilityHint("Opens a DEBUG-only page for configuring and diagnosing the Plaid sandbox broker used in Phase 5D real-device validation.")
        } header: {
            Text("Developer tools")
        } footer: {
            Text("Only present in DEBUG builds. This is a bounded validation harness for Phase 5D — it does not enable production bank connections.")
        }
    }
#endif
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
            Text("Manual entry and CSV import are always available.")
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
#if DEBUG
                    plaidValidationRecorder.recordLinkLaunchRequested()
#endif
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
            Text("NomadFi syncs only when you tap Sync Now.")
        }
    }
}

// MARK: - Helpers

private extension FinancialConnectionsSettingsView {

    func runSync(viewModel: FinancialConnectionsViewModel) async {
        let (start, end) = defaultSyncWindow()
#if DEBUG
        plaidValidationRecorder.recordSyncStarted(windowStart: start, windowEnd: end)
#endif
        await viewModel.syncNow(
            from: start,
            to: end,
            modelContext: modelContext,
            existingAccounts: accounts,
            existingTransactions: transactions
        )
#if DEBUG
        if let report = viewModel.lastSyncReport {
            plaidValidationRecorder.recordSyncFinished(report: report)
        }
        if let result = viewModel.lastReconciliation {
            plaidValidationRecorder.recordReconciliationFinished(result: result)
        }
#endif
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
