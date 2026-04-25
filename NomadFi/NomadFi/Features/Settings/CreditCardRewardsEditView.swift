// CreditCardRewardsEditView.swift
// NomadFi
//
// Focused editor for a credit-card account's rewards terms. Follows
// the same shape as ``CreditCardScheduleEditView`` — native `Form`
// sections, explicit Save / clear semantics, provenance captured
// alongside the rate so unverified rewards never graduate into the
// ranker.

import SwiftUI

/// Push-style editor for a credit card's rewards program, base
/// earn rate, category overrides, and source provenance.
struct CreditCardRewardsEditView: View {

    @State private var viewModel: CreditCardRewardsEditViewModel
    @State private var isShowingClearConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case programName
        case baseRate
        case categoryOverride(MerchantCategory)
        case sourceName
        case sourceURL
        case notes
    }

    init(account: Account) {
        _viewModel = State(initialValue: CreditCardRewardsEditViewModel(account: account))
    }

    var body: some View {
        Form {
            programSection
            baseRateSection
            categoryOverridesSection
            sourceSection
            verificationSection
            notesSection
            clearSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(viewModel.account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    focusedField = nil
                    viewModel.save()
                    dismiss()
                }
                .disabled(!viewModel.canSave)
                .accessibilityHint("Saves the rewards terms for this card.")
            }
        }
        .keyboardDoneAccessory(focused: $focusedField)
        .confirmationDialog(
            "Clear rewards terms?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Rewards", role: .destructive) {
                viewModel.clearRewards()
            }
        } message: {
            Text("This removes the program name, rates, and source for this card. You can re-enter them at any time.")
        }
    }
}

// MARK: - Sections

private extension CreditCardRewardsEditView {

    var programSection: some View {
        Section {
            TextField(
                "Program name",
                text: $viewModel.programName
            )
            .textInputAutocapitalization(.words)
            .focused($focusedField, equals: .programName)
            .accessibilityLabel("Rewards program name")
            .accessibilityHint("Optional. A short name like the issuer's program, for example Freedom Rise or Cobalt.")

            Picker("Unit", selection: $viewModel.unit) {
                ForEach(RewardUnit.allCases, id: \.self) { unit in
                    Text(unit.displayLabel)
                        .tag(unit)
                        .accessibilityLabel(unit.accessibilityLabel)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Program")
        } footer: {
            Text("Unit determines what the rate means (for example, 1.5% cash back versus 1 point per dollar). NomadFi does not convert between units.")
        }
    }

    var baseRateSection: some View {
        Section {
            TextField(
                "Base rate",
                text: $viewModel.baseRateText
            )
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: .baseRate)
            .accessibilityLabel("Base earn rate")
            .accessibilityHint("Applied when no category override matches the purchase category.")
        } header: {
            Text("Base earn rate")
        } footer: {
            Text("Enter the rate the issuer publishes as the \"everywhere else\" earn rate. Leave empty if you don't want a base rate on file.")
        }
    }

    var categoryOverridesSection: some View {
        Section {
            ForEach(MerchantCategory.allCases, id: \.self) { category in
                HStack(alignment: .firstTextBaseline) {
                    Label {
                        Text(category.displayLabel)
                            .font(TypographyTokens.body)
                    } icon: {
                        Image(systemName: category.systemImage)
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    TextField(
                        "Override",
                        text: overrideBinding(for: category)
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .categoryOverride(category))
                    .frame(maxWidth: 110)
                    .accessibilityLabel("\(category.accessibilityLabel) override rate")
                    .accessibilityHint("Leave empty to use the base rate.")
                }
            }
        } header: {
            Text("Category overrides")
        } footer: {
            Text("Optional. Enter only the categories where the issuer publishes a different rate. Empty fields use the base rate.")
        }
    }

    var sourceSection: some View {
        Section {
            TextField(
                "Source name",
                text: $viewModel.sourceName
            )
            .textInputAutocapitalization(.words)
            .focused($focusedField, equals: .sourceName)
            .accessibilityLabel("Source name")
            .accessibilityHint("For example, the exact issuer product page title.")

            TextField(
                "Source URL",
                text: $viewModel.sourceURL
            )
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .sourceURL)
            .accessibilityLabel("Source URL")
            .accessibilityHint("Link to the issuer's official product page or cardmember agreement.")

            Picker(
                "Source confidence",
                selection: $viewModel.sourceConfidence
            ) {
                ForEach(SourceConfidence.allCases, id: \.self) { confidence in
                    Text(confidence.displayLabel).tag(confidence)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Source")
        } footer: {
            Text("NomadFi treats rewards as verified only when an official source is attached and has been verified recently. Reddit, YouTube, and affiliate blogs are not acceptable sources.")
        }
    }

    var verificationSection: some View {
        Section {
            if let verifiedAt = viewModel.sourceVerifiedAt {
                LabeledContent("Last verified") {
                    Text(verifiedAt, format: .dateTime.year().month(.wide).day())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last verified \(verifiedAt.formatted(.dateTime.year().month(.wide).day()))")
            }

            Button(
                "Mark Verified Today",
                systemImage: "checkmark.seal"
            ) {
                viewModel.markVerifiedToday()
            }
            .disabled(!viewModel.hasSource)
            .accessibilityHint(
                viewModel.hasSource
                    ? "Stamps today's date as the last time you verified these rewards terms against the issuer."
                    : "Add a source name or URL before marking as verified."
            )
        } header: {
            Text("Verification")
        } footer: {
            Text("The verified-today stamp is informational only. NomadFi does not contact your issuer.")
        }
    }

    var notesSection: some View {
        Section {
            TextField(
                "Notes",
                text: $viewModel.notes,
                axis: .vertical
            )
            .lineLimit(2...5)
            .focused($focusedField, equals: .notes)
            .accessibilityLabel("Rewards notes")
            .accessibilityHint("Optional. Add caveats the engine should show alongside the rate.")
        } header: {
            Text("Notes")
        }
    }

    var clearSection: some View {
        Section {
            Button(
                "Clear Rewards Terms",
                systemImage: "trash",
                role: .destructive
            ) {
                isShowingClearConfirmation = true
            }
            .disabled(
                !viewModel.hasAnyRateEntered
                && !viewModel.hasSource
                && viewModel.programName.trimmingCharacters(in: .whitespaces).isEmpty
            )
            .accessibilityHint("Removes the program, rates, and source for this card.")
        }
    }

    func overrideBinding(for category: MerchantCategory) -> Binding<String> {
        Binding(
            get: { viewModel.categoryOverrideTexts[category] ?? "" },
            set: { viewModel.categoryOverrideTexts[category] = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        CreditCardRewardsEditView(
            account: Account(
                name: "Sample Rewards",
                institutionName: "Example Credit Union",
                accountType: .creditCard,
                currencyCode: .usd,
                jurisdiction: "US"
            )
        )
    }
}
