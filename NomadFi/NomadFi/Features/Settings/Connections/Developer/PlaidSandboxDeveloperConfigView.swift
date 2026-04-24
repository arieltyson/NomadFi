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
    @Environment(\.plaidValidationRecorder) private var recorder

    @State private var viewModel: PlaidSandboxDeveloperConfigViewModel
    @State private var sessionNoteDraft: String = ""
    @State private var selectedResult: PlaidValidationSession.Result = .pending
    @State private var sharedExport: ValidationExportPayload?

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
            validationSessionSection
            resetSection
        }
        .navigationTitle("Plaid Sandbox Harness")
        .glassToolbar()
        .sheet(item: $sharedExport) { payload in
            ShareSheet(activityItems: payload.activityItems)
                .presentationDetents([.medium, .large])
        }
    }
}

/// A single shared-export payload wrapped in `Identifiable` so
/// `.sheet(item:)` can present it.
private struct ValidationExportPayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
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
                viewModel.save(recorder: recorder)
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
                Task { await viewModel.runHealthCheck(recorder: recorder) }
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
                viewModel.clearLinkedItem(recorder: recorder)
            } label: {
                Label("Clear linked item + cursor", systemImage: "arrow.uturn.backward.circle")
            }
            .accessibilityHint("Removes the stored Plaid item handle and incremental-sync cursor so a retry Link attempt starts clean.")
        } header: {
            Text("Plaid item state")
        }
    }

    /// Section that drives the DEBUG-only Phase 5D validation
    /// recorder: start a fresh session, mark a result, export a
    /// redacted JSON or Markdown artifact.
    @ViewBuilder
    var validationSessionSection: some View {
        Section {
            if recorder.currentSession != nil {
                sessionRunningView
            } else if recorder.lastFinalizedSession != nil {
                finalizedSessionView
            } else {
                Button {
                    recorder.startSession()
                    sessionNoteDraft = ""
                    selectedResult = .pending
                } label: {
                    Label("Start validation session", systemImage: "record.circle")
                }
                .accessibilityHint("Begins recording broker + Plaid Link events so they can be exported as a redacted evidence artifact.")
            }
        } header: {
            Text("Validation recorder")
        } footer: {
            Text("Captures redacted evidence for Phase 5D criterion 5. Events never include Plaid tokens, broker URL/host details, or shared secrets. Exports are safe to paste back for analysis.")
        }
    }

    @ViewBuilder
    private var sessionRunningView: some View {
        if let current = recorder.currentSession {
            Text("\(current.events.count) events recorded")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }

        Toggle(
            "Include institution name in export",
            isOn: Bindable(recorder).includesInstitutionName
        )
        .accessibilityHint("When on, the Plaid-reported institution display name is included in the exported artifact.")

        Picker("Result", selection: $selectedResult) {
            Text("Pending").tag(PlaidValidationSession.Result.pending)
            Text("Pass").tag(PlaidValidationSession.Result.pass)
            Text("Fail").tag(PlaidValidationSession.Result.fail)
            Text("Inconclusive").tag(PlaidValidationSession.Result.inconclusive)
        }

        TextField(
            "Note (optional)",
            text: $sessionNoteDraft,
            prompt: Text("One-line note added to the exported artifact"),
            axis: .vertical
        )
        .lineLimit(1...3)

        Button {
            let trimmed = sessionNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            recorder.recordResultMarked(selectedResult)
            if !trimmed.isEmpty {
                recorder.recordNote(trimmed)
            }
            recorder.endSession(
                result: selectedResult,
                note: trimmed.isEmpty ? nil : trimmed
            )
        } label: {
            Label("End session", systemImage: "stop.circle")
        }
        .disabled(selectedResult == .pending)
    }

    @ViewBuilder
    private var finalizedSessionView: some View {
        if let session = recorder.lastFinalizedSession {
            Text("Last session: \(session.result.rawValue) (\(session.events.count) events)")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }

        Button {
            if let markdown = recorder.exportMarkdown() {
                sharedExport = ValidationExportPayload(activityItems: [markdown])
            }
        } label: {
            Label("Export as Markdown", systemImage: "doc.richtext")
        }
        .disabled(recorder.lastFinalizedSession == nil)

        Button {
            if let data = try? recorder.exportJSON(),
               let string = String(data: data, encoding: .utf8) {
                sharedExport = ValidationExportPayload(activityItems: [string])
            }
        } label: {
            Label("Export as JSON", systemImage: "curlybraces")
        }
        .disabled(recorder.lastFinalizedSession == nil)

        Button(role: .destructive) {
            recorder.clearLastFinalizedSession()
        } label: {
            Label("Discard last session", systemImage: "trash")
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

/// Minimal `UIActivityViewController` wrapper so the DEBUG-only
/// export flow can use iOS's system share sheet (Save to Files,
/// Mail, AirDrop, Messages, Copy). Only compiled in DEBUG.
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview("Plaid sandbox developer config") {
    NavigationStack {
        PlaidSandboxDeveloperConfigView()
    }
}

#endif
