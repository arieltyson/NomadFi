// DecisionDraftFormView.swift
// NomadFi
//
// Capture sheet for the Decision Assistant's "Gathered intelligence"
// flow. The form is intentionally plain on the surface — no AI
// affordance, no "analyze" button — because NomadFi does not yet
// ship a deterministic engine for user-captured drafts. Save
// confirms the draft is stored on-device and marked "needs engine".
//
// Accessibility:
//   - Every field has an explicit `accessibilityLabel`.
//   - The kind picker announces via the typed accessibility label,
//     not the SF Symbol.
//   - Dynamic Type scales through `TypographyTokens` and through
//     Form's built-in scaling.
//   - `.scrollDismissesKeyboard(.interactively)` lets keyboard users
//     drop focus without tapping the toolbar button.

import SwiftData
import SwiftUI

/// Modal sheet for capturing a new decision draft.
struct DecisionDraftFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = DecisionDraftFormViewModel()
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                scenarioSection
                contextSection
                financialSection
                notesSection
                integritySection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Capture decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var scenarioSection: some View {
        Section {
            Picker("Kind", selection: $viewModel.kind) {
                ForEach(DecisionDraftKind.allCases, id: \.self) { kind in
                    Label(kind.displayLabel, systemImage: kind.systemImage)
                        .tag(kind)
                        .accessibilityLabel(kind.accessibilityLabel)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Decision kind")

            TextField(
                "Short title (optional)",
                text: $viewModel.title,
                axis: .vertical
            )
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .accessibilityLabel("Short title, optional")
        } header: {
            Text("What kind of decision is it?")
        } footer: {
            Text("A short title helps you recognise this draft in the Gathered intelligence list.")
                .font(TypographyTokens.caption)
        }

        Section {
            TextEditor(text: $viewModel.scenarioText)
                .frame(minHeight: 140)
                .focused($focusedField, equals: .scenario)
                .accessibilityLabel("Scenario description")
        } header: {
            Text("Describe the scenario")
        } footer: {
            Text("Use your own words — merchant, context, and what you're weighing. This is the only required field.")
                .font(TypographyTokens.caption)
        }
    }

    private var contextSection: some View {
        Section {
            TextField(
                "Merchant or counterparty",
                text: $viewModel.merchantName
            )
            .focused($focusedField, equals: .merchant)
            .submitLabel(.next)
            .accessibilityLabel("Merchant or counterparty")

            TextField(
                "City or context",
                text: $viewModel.locationText
            )
            .focused($focusedField, equals: .location)
            .textInputAutocapitalization(.words)
            .submitLabel(.next)
            .accessibilityLabel("City or context")
            .accessibilityHint("A short location hint, not a full address.")

            TextField(
                "When, in your own words",
                text: $viewModel.timingText
            )
            .focused($focusedField, equals: .timing)
            .submitLabel(.next)
            .accessibilityLabel("Timing in your own words")
        } header: {
            Text("Context")
        } footer: {
            Text("Keep location to a city or short hint. Don't enter addresses, card numbers, or account details.")
                .font(TypographyTokens.caption)
        }
    }

    private var financialSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                TextField("Amount (optional)", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .accessibilityLabel("Amount, optional")

                Picker("Currency", selection: $viewModel.currencyCode) {
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
        } footer: {
            Text("Optional. Leave blank if the decision isn't primarily financial.")
                .font(TypographyTokens.caption)
        }
    }

    private var notesSection: some View {
        Section {
            TextField(
                "Notes (optional)",
                text: $viewModel.notes,
                axis: .vertical
            )
            .lineLimit(2...5)
            .focused($focusedField, equals: .notes)
            .accessibilityLabel("Notes, optional")
        } header: {
            Text("Notes")
        }
    }

    private var integritySection: some View {
        Section {
            Label {
                Text("Saved drafts stay on this device and are marked **Needs engine** until a deterministic NomadFi engine covers this kind. NomadFi does not auto-analyze drafts with generic AI.")
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
            }
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Saved drafts stay on this device and are marked needs engine until a deterministic NomadFi engine covers this kind. NomadFi does not auto-analyze drafts with generic AI.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                focusedField = nil
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                focusedField = nil
                if viewModel.save(into: modelContext) != nil {
                    dismiss()
                }
            }
            .disabled(!viewModel.canSave)
            .accessibilityHint("Saves the draft on this device. NomadFi does not analyze it yet.")
        }

        KeyboardDismissToolbarItem {
            focusedField = nil
        }
    }
}

// MARK: - Focus

private extension DecisionDraftFormView {

    enum Field: Hashable {
        case title
        case scenario
        case merchant
        case location
        case timing
        case amount
        case notes
    }
}

#Preview {
    DecisionDraftFormView()
        .modelContainer(
            for: [
                DecisionDraftRecord.self,
            ],
            inMemory: true
        )
}
