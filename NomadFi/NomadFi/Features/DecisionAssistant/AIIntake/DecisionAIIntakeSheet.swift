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

    /// Optional pre-seed scenario string the parent supplies when
    /// the sheet was opened from a system-surface hand-off (Siri /
    /// App Shortcut via `OpenAIIntakeIntent`). Applied once on
    /// `.task` if the view-model's scenario field is still empty,
    /// so user typing always wins on a freshly opened sheet and
    /// re-opens never silently re-seed previously-typed text.
    let seedScenarioText: String

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
        seedScenarioText: String = "",
        onSavedDraft: @escaping (DecisionDraftRecord) -> Void,
        onSwitchToTypedForm: @escaping () -> Void
    ) {
        _viewModel = State(
            wrappedValue: DecisionAIIntakeViewModel(interpreter: interpreter)
        )
        self.seedScenarioText = seedScenarioText
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
        .task {
            viewModel.refreshAvailability()
            applySeedIfNeeded()
        }
    }

    /// Applies `seedScenarioText` to the view-model's scenario
    /// field exactly once per sheet presentation, and only when
    /// the user hasn't already typed something. Keeps the user in
    /// control on every subsequent re-render — see Apple's
    /// Generative AI HIG: no hidden side effects.
    private func applySeedIfNeeded() {
        let trimmedSeed = seedScenarioText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedSeed.isEmpty,
              viewModel.scenarioText.isEmpty
        else { return }
        viewModel.scenarioText = trimmedSeed
    }

    // MARK: - Stage routing

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .capture:
            captureContent
        case .interpreting:
            interpretingContent
        case .clarifying:
            clarifyingContent
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
        case .clarifying: "A couple of follow-ups"
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

    // MARK: - Clarifying

    /// Bounded follow-up loop. Renders one question at a time so
    /// the user is never asked to scan a wall of unresolved
    /// fields. Apple HIG generative-AI guidance: progressive
    /// disclosure, AI usage clearly disclosed, fallback always
    /// reachable.
    @ViewBuilder
    private var clarifyingContent: some View {
        if let question = viewModel.currentClarifyingQuestion {
            ClarifyingQuestionForm(
                question: question,
                progressLabel: clarifyingProgressLabel,
                draftText: $viewModel.clarificationDraftText,
                draftCurrency: $viewModel.clarificationDraftCurrency,
                draftKind: $viewModel.clarificationDraftKind,
                canSubmit: viewModel.canSubmitClarificationAnswer,
                onContinue: { viewModel.submitClarificationAnswer() },
                onSkip: { viewModel.skipCurrentClarification() },
                onSkipAll: { viewModel.skipAllClarification() },
                onSwitchToTypedForm: onSwitchToTypedForm
            )
        } else {
            // Defensive — should never render. The view model
            // transitions to .review when the plan empties.
            ProgressView()
                .controlSize(.regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }

    /// Short "Question N of M" string for the progress affordance
    /// at the top of the clarifying form. Voiceover-friendly.
    private var clarifyingProgressLabel: String {
        guard case let .clarifying(index) = viewModel.stage else { return "" }
        let total = viewModel.clarificationPlan.count
        guard total > 0 else { return "" }
        return "Question \(index + 1) of \(total)"
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

// MARK: - Clarifying-question form

/// Renders one clarifying question at a time with the calmest
/// possible affordance ladder per Apple HIG generative-AI
/// guidance:
///
///   • The question is the headline. The optional helper line
///     explains *why* NomadFi is asking, never what the user
///     "should" do.
///   • One input control per question (`TextField`, decimal pad,
///     `Picker`). Picker styles match the rest of the intake
///     form so the user sees consistent controls across stages.
///   • Three escape hatches: Continue (primary), Skip this
///     question (secondary), Skip all clarifying questions
///     (tertiary), and Use the typed form instead (also tertiary).
///   • A visible "Question N of M" progress affordance keeps the
///     user oriented; VoiceOver reads the same string as the
///     accessibility value of the form section.
private struct ClarifyingQuestionForm: View {

    let question: DecisionAIClarifyingQuestion
    let progressLabel: String

    @Binding var draftText: String
    @Binding var draftCurrency: CurrencyCode
    @Binding var draftKind: DecisionDraftKind

    let canSubmit: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onSkipAll: () -> Void
    let onSwitchToTypedForm: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        Form {
            Section {
                progressRow
                Text(question.prompt)
                    .font(TypographyTokens.sectionHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let helper = question.helper {
                    Text(helper)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            Section {
                inputControl
            } footer: {
                Text("AI structures input. Deterministic engines decide. NomadFi will not save anything until you confirm on the next screen.")
                    .font(TypographyTokens.caption)
            }

            Section {
                NomadFiActionButton(
                    title: "Continue",
                    systemImage: "arrow.right.circle",
                    style: .primary,
                    controlSize: .large,
                    accessibilityHint: "Folds your answer into the pending draft and advances to the next question or the review screen.",
                    action: onContinue
                )
                .disabled(!canSubmit)

                NomadFiActionButton(
                    title: "Skip this question",
                    systemImage: "chevron.right",
                    style: .secondary,
                    accessibilityHint: "Leaves this field blank for now. You can fill it on the review screen.",
                    action: onSkip
                )

                NomadFiActionButton(
                    title: "Skip clarifying questions",
                    systemImage: "checkmark",
                    style: .tertiary,
                    fillsWidth: false,
                    accessibilityHint: "Goes straight to the review screen — any remaining gaps stay blank until you fill them there.",
                    action: onSkipAll
                )

                NomadFiActionButton(
                    title: "Use the typed form instead",
                    systemImage: "square.and.pencil",
                    style: .tertiary,
                    fillsWidth: false,
                    accessibilityHint: "Closes this sheet and opens the typed draft form.",
                    action: onSwitchToTypedForm
                )
            }
        }
        .onAppear { isInputFocused = true }
    }

    /// Tiny visual + accessibility row showing the user where they
    /// are in the bounded clarification loop.
    private var progressRow: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
            Text(progressLabel)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progressLabel)
    }

    /// Single input control matched to the question's `inputKind`.
    /// Centralised here so the parent sheet stays a thin router and
    /// the control choice cannot drift across questions.
    @ViewBuilder
    private var inputControl: some View {
        switch question.inputKind {
        case .shortText(let placeholder):
            TextField(placeholder, text: $draftText)
                .textInputAutocapitalization(.sentences)
                .focused($isInputFocused)
                .accessibilityLabel(question.prompt)
        case .amount(let placeholder):
            TextField(placeholder, text: $draftText)
                .keyboardType(.decimalPad)
                .focused($isInputFocused)
                .accessibilityLabel(question.prompt)
        case .currency:
            Picker(question.prompt, selection: $draftCurrency) {
                ForEach(CurrencyCode.allCases) { code in
                    Text(code.rawValue).tag(code)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(question.prompt)
        case .kind:
            Picker(question.prompt, selection: $draftKind) {
                ForEach(DecisionDraftKind.allCases, id: \.self) { kind in
                    Label(kind.displayLabel, systemImage: kind.systemImage)
                        .tag(kind)
                        .accessibilityLabel(kind.accessibilityLabel)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(question.prompt)
        }
    }
}
