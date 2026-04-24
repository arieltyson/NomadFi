// PlaidSandboxDeveloperConfigView.swift
// NomadFi
//
// Developer-only diagnostics + configuration page for the Plaid
// *sandbox* validation harness. Compiled only in DEBUG builds. The
// entire file is wrapped in `#if DEBUG` so it cannot accidentally
// ship in a Release binary.
//
// This page never claims production coverage. Every label on it is
// explicitly scoped to the Phase 5D validation harness.

#if DEBUG

import SwiftData
import SwiftUI

struct PlaidSandboxDeveloperConfigView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PlaidSandboxDeveloperConfigViewModel

    init(
        viewModel: PlaidSandboxDeveloperConfigViewModel = PlaidSandboxDeveloperConfigViewModel()
    ) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            brokerSection
            healthSection
            linkedItemSection
            resetSection
        }
        .navigationTitle("Plaid Sandbox Harness")
        .glassToolbar()
    }
}

// MARK: - Sections

private extension PlaidSandboxDeveloperConfigView {

    var brokerSection: some View {
        Section {
            TextField(
                "Broker URL",
                text: $viewModel.brokerURLText,
                prompt: Text("http://192.168.x.x:8787")
            )
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .accessibilityHint("Base URL for the developer-only Plaid sandbox broker running on your local network.")

            SecureField(
                "Shared secret (optional)",
                text: $viewModel.brokerSecretText,
                prompt: Text("Required only in LAN mode")
            )
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityHint("The PLAID_BROKER_SHARED_SECRET configured on the developer machine.")

            Button {
                viewModel.save()
            } label: {
                Label("Save broker config", systemImage: "tray.and.arrow.down")
            }
            .disabled(!viewModel.canSave)

            if let outcome = viewModel.lastSaveOutcome {
                Text(outcome.label)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Developer-only broker")
        } footer: {
            Text("This page is compiled into DEBUG builds only. It configures a local Plaid sandbox broker used for Phase 5D real-device validation. Plaid client_id and secret never leave the broker.")
        }
    }

    var healthSection: some View {
        Section {
            Button {
                Task { await viewModel.runHealthCheck() }
            } label: {
                Label("Run health check", systemImage: "stethoscope")
            }
            .disabled(viewModel.isHealthChecking)

            Label {
                Text(viewModel.healthStatus.label)
            } icon: {
                Image(systemName: viewModel.healthStatus.iconName)
            }
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
        } header: {
            Text("Broker health")
        } footer: {
            Text("Health checks only report broker reachability and configuration. They never imply bank coverage.")
        }
    }

    var linkedItemSection: some View {
        Section {
            Text(viewModel.linkedItemSummary.label)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                viewModel.clearLinkedItem()
            } label: {
                Label("Clear linked item + cursor", systemImage: "arrow.uturn.backward.circle")
            }
            .accessibilityHint("Removes the stored Plaid item handle and incremental-sync cursor so a retry Link attempt starts clean.")
        } header: {
            Text("Plaid item state")
        }
    }

    var resetSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.resetAll()
            } label: {
                Label("Reset all Plaid sandbox state", systemImage: "trash")
            }
            .accessibilityHint("Clears broker URL, shared secret, linked item handle, and sync cursor.")
        } footer: {
            Text("This only clears values the app persists locally. Plaid broker state on the developer machine is unaffected.")
        }
    }
}

#Preview("Plaid sandbox developer config") {
    NavigationStack {
        PlaidSandboxDeveloperConfigView()
    }
}

#endif
