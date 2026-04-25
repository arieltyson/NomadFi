// DecisionAIIntakeSheet.swift
// NomadFi
//
// Phase 9A — Apple Intelligence intake sheet. Three stages:
//
//   1. Capture — scenario textfield + "Interpret" button.
//   2. Interpreting — progress affordance.
//   3. Review — editable form pre-seeded from the interpretation
//      with explicit "Save draft" / "Back" controls.
//
// Honesty contract surfaced in copy:
//
//   • The user is the one who saves. AI structures input;
//     deterministic engines decide.
//   • Missing fields are listed verbatim from the interpreter so
//     the user knows what they're filling in.
//   • Unavailable states render a calm headline + a "Capture
//     with the typed form instead" affordance.

import SwiftData
import SwiftUI

/// Modal intake sheet that turns natural-language scenarios into
/// structured `DecisionDraftRecord`s, with an explicit user
/// confirmation step in between.
struct DecisionAIIntakeSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DecisionAIIntakeViewModel

    /// Closure the sheet calls after a successful save so the
    /// parent (`DecisionAssistantView`) can open the existing
    /// detail sheet for the freshly-inserted draft.
    let onSavedDraft: (DecisionDraftRecord) -> Void

    /// Closure the sheet calls when the user wants to drop into
    /// the typed form instead of the AI flow. The parent dismisses
    /// this sheet and presents `DecisionDraftFormView`.
    let onSwitchToTypedForm: () -> Void

    init(
        interpreter: DecisionDraftInterpreter,
        onSavedDraft: @escaping (DecisionDraftRecord) -> Void,
        onSwitchToTypedForm: @escaping () -> Void
    ) {
        _viewModel = State(
            wrappedValue: DecisionAIIntakeViewModel(interpreter: interpreter)
        )
        self.onSavedDraft = onSavedDraft
        self.onSwitchToTypedForm = onSwitchToTypedForm
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .task { viewModel.refreshAvailability() }
    }

    // MARK: - Stage routing

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .capture:
            captureContent
        case .interpreting:
            interpretingContent
        case .review:
            reviewContent
        case .failed(let reason):
            failedContent(reason: reason)
        }
    }

    private var navigationTitle: String {
        switch viewModel.stage {
        case .capture: "Apple Intelligence intake"
        case .interpreting: "Interpreting…"
        case .review: "Review extracted fields"
        case .failed: "Couldn't interpret"
        }
    }

    // MARK: - Capture

    @ViewBuilder
    private var captureContent: some View {
        Form {
            if let headline = viewModel.availability.unavailableHeadline {
                Section {
                    Label {
                        Text(headline)
                            .font(TypographyTokens.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)

                    NomadFiActionButton(
                        title: "Capture with the typed form instead",
                        systemImage: "square.and.pencil",
                        style: .secondary,
                        fillsWidth: false,
                        accessibilityHint: "Closes this sheet and opens the typed draft form.",
                        action: onSwitchToTypedForm
                    )
                }
            } else {
                Section {
                    TextEditor(text: $viewModel.scenarioText)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Scenario description")
                } header: {
                    Text("Paste or type the scenario")
                } footer: {
                    Text("NomadFi runs Apple Intelligence on this device only. The model extracts structured inputs — it does not recommend a card, account, or payment method.")
                        .font(TypographyTokens.caption)
                }

                Section {
                    NomadFiActionButton(
                        title: "Interpret on device",
                        systemImage: "apple.intelligence",
                        style: .primary,
                        controlSize: .large,
                        accessibilityHint: "Asks the on-device model to structure this scenario into draft fields. You will review and confirm before saving.",
                        action: { Task { await viewModel.interpret() } }
                    )
                    .disabled(!viewModel.canInterpret)
                }
            }
        }
    }

    // MARK: - Interpreting

    private var interpretingContent: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .controlSize(.large)
            Text("Asking the on-device model to structure your scenario…")
                .font(TypographyTokens.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, SpacingTokens.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Review

    @ViewBuilder
    private var reviewContent: some View {
        Form {
            if let confidenceNote = viewModel.confidenceNote {
                Section {
                    Label {
                        Text(confidenceNote)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .accessibilityHidden(true)
                    }
                }
            }

            if !viewModel.missingFields.isEmpty {
                Section {
                    ForEach(viewModel.missingFields, id: \.self) { field in
                        Label {
                            Text(field.displayLabel)
                                .font(TypographyTokens.body)
                        } icon: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(ColorTokens.warning)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Add before saving")
                } footer: {
                    Text("The model left these blank. Fill them in below before saving the draft, or save as-is and finish in the draft detail sheet.")
                        .font(TypographyTokens.caption)
                }
            }

            Section {
                Picker("Kind", selection: $viewModel.reviewKind) {
                    ForEach(DecisionDraftKind.allCases, id: \.self) { kind in
                        Label(kind.displayLabel, systemImage: kind.systemImage)
                            .tag(kind)
                            .accessibilityLabel(kind.accessibilityLabel)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Decision kind")

                TextField("Short title (optional)", text: $viewModel.reviewTitle)
                    .accessibilityLabel("Short title, optional")
            } header: {
                Text("Decision")
            }

            Section {
                TextField("Merchant or counterparty", text: $viewModel.reviewMerchantName)
                    .accessibilityLabel("Merchant or counterparty")
                TextField("City or context", text: $viewModel.reviewLocationText)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("City or context")
                    .accessibilityHint("Short hint, not a full address.")
                TextField("When, in your own words", text: $viewModel.reviewTimingText)
                    .accessibilityLabel("Timing in your own words")
            } header: {
                Text("Context")
            }

            Section {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                    TextField("Amount (optional)", text: $viewModel.reviewAmountText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Amount, optional")

                    Picker("Currency", selection: $viewModel.reviewCurrencyCode) {
                        ForEach(CurrencyCode.allCases) { code in
                            Text(code.rawValue).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel("Currency")
                }
            } header: {
                Text("Amount")
            }

            Section {
                TextField(
                    "Notes (optional)",
                    text: $viewModel.reviewNotes,
                    axis: .vertical
                )
                .lineLimit(2...5)
                .accessibilityLabel("Notes, optional")
            } header: {
                Text("Notes")
            }

            Section {
                TextEditor(text: $viewModel.scenarioText)
                    .frame(minHeight: 100)
                    .accessibilityLabel("Scenario description")
            } header: {
                Text("Scenario")
            } footer: {
                Text("AI structures input. Deterministic engines decide. NomadFi will mark this draft Needs engine until you tap a handoff button on the detail sheet.")
                    .font(TypographyTokens.caption)
            }
        }
    }

    // MARK: - Failed

    private func failedContent(reason: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            Label {
                Text(reason)
                    .font(TypographyTokens.body)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(ColorTokens.warning)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)

            NomadFiActionButton(
                title: "Edit scenario and try again",
                systemImage: "arrow.uturn.backward",
                style: .secondary,
                fillsWidth: false,
                action: { viewModel.backToCapture() }
            )

            NomadFiActionButton(
                title: "Capture with the typed form instead",
                systemImage: "square.and.pencil",
                style: .secondary,
                fillsWidth: false,
                action: onSwitchToTypedForm
            )

            Spacer()
        }
        .padding(SpacingTokens.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                viewModel.reset()
                dismiss()
            }
        }

        if case .review = viewModel.stage {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save draft") {
                    if let saved = viewModel.confirmAndSave(in: modelContext) {
                        dismiss()
                        onSavedDraft(saved)
                    }
                }
                .disabled(!viewModel.canSave)
                .accessibilityHint("Saves the AI-assisted draft on this device. NomadFi will not analyze it automatically.")
            }
        }
    }
}
