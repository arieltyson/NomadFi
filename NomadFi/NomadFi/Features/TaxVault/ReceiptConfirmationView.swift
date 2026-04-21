// ReceiptConfirmationView.swift
// NomadFi
//
// Confirmation sheet presented after a receipt is scanned via OCR.
// Lets the user review and adjust extracted data before saving.

import SwiftData
import SwiftUI

/// A sheet view for reviewing and confirming scanned receipt data before saving.
///
/// Pre-populates fields from the OCR scan result and auto-categorization.
/// The user can adjust any field before confirming. Provides clear feedback
/// on auto-categorization confidence.
struct ReceiptConfirmationView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \JurisdictionProfile.displayOrder) private var jurisdictions: [JurisdictionProfile]

    @Bindable var viewModel: TaxVaultViewModel
    @State private var saveCount = 0

    @FocusState private var focusedField: Field?

    enum Field {
        case merchant
        case amount
    }

    var body: some View {
        NavigationStack {
            Form {
                scanResultPreview

                merchantSection

                amountSection

                categorizationSection

                lineItemsSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Confirm Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityHint("Dismisses this sheet without saving the scanned receipt.")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveConfirmedDocument(modelContext: modelContext)
                        saveCount += 1
                        dismiss()
                    }
                    .bold()
                    .disabled(viewModel.draftMerchantName.isEmpty)
                    .accessibilityHint("Saves this receipt to Tax Vault with the current details.")
                }
            }
            .keyboardDismissToolbar { focusedField = nil }
            .sensoryFeedback(.success, trigger: saveCount)
        }
    }
}

// MARK: - Sections

private extension ReceiptConfirmationView {

    // MARK: Scan Preview

    var scanResultPreview: some View {
        Section {
            if let result = viewModel.scanResult {
                ConfidenceBanner(
                    text: result.rawText,
                    category: viewModel.draftTaxCategory,
                    jurisdiction: viewModel.draftJurisdiction
                )
            }
        }
    }

    // MARK: Merchant Info

    var merchantSection: some View {
        Section("Merchant") {
            TextField("Merchant name", text: $viewModel.draftMerchantName)
                .focused($focusedField, equals: .merchant)
                .textContentType(.organizationName)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focusedField = .amount }

            DatePicker(
                "Date",
                selection: $viewModel.draftDocumentDate,
                displayedComponents: .date
            )
        }
    }

    // MARK: Amount

    var amountSection: some View {
        Section("Amount") {
            HStack {
                Text(viewModel.draftCurrencyCode.symbol)
                    .foregroundStyle(.secondary)

                TextField(
                    "Amount",
                    value: $viewModel.draftAmount,
                    format: .number.precision(.fractionLength(2))
                )
                .focused($focusedField, equals: .amount)
                .keyboardType(.decimalPad)
                .textContentType(.none)
                .autocorrectionDisabled()
            }

            Picker("Currency", selection: $viewModel.draftCurrencyCode) {
                ForEach(CurrencyCode.allCases) { code in
                    Text(code.displayName)
                        .tag(code)
                }
            }
        }
    }

    // MARK: Categorization

    var categorizationSection: some View {
        Section("Categorization") {
            Picker("Tax Category", selection: $viewModel.draftTaxCategory) {
                ForEach(TaxCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.systemImage)
                        .tag(category)
                }
            }

            Picker("Jurisdiction", selection: $viewModel.draftJurisdiction) {
                Text("None")
                    .tag("")
                ForEach(jurisdictions) { jurisdiction in
                    Text("\(String.flagEmoji(for: jurisdiction.countryCode)) \(jurisdiction.countryName)")
                        .tag(jurisdiction.countryCode)
                }
            }
        }
    }

    // MARK: Line Items

    @ViewBuilder
    var lineItemsSection: some View {
        if let result = viewModel.scanResult, !result.lineItems.isEmpty {
            Section("Detected Line Items") {
                ForEach(result.lineItems.indices, id: \.self) { index in
                    ReceiptLineItemRow(
                        item: result.lineItems[index],
                        currencyCode: viewModel.draftCurrencyCode,
                        useAccessibilityLayout: dynamicTypeSize.isAccessibilitySize
                    )
                }
            }
        }
    }
}

private struct ReceiptLineItemRow: View {

    let item: ReceiptLineItem
    let currencyCode: CurrencyCode
    let useAccessibilityLayout: Bool

    var body: some View {
        Group {
            if useAccessibilityLayout {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    descriptionText

                    if let amount = item.amount {
                        amountText(amount)
                    }
                }
            } else {
                HStack {
                    descriptionText

                    Spacer()

                    if let amount = item.amount {
                        amountText(amount)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var descriptionText: some View {
        Text(item.description)
            .font(TypographyTokens.body)
            .lineLimit(useAccessibilityLayout ? 3 : 1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func amountText(_ amount: Double) -> some View {
        Text(
            amount,
            format: .currency(code: currencyCode.rawValue)
        )
        .font(TypographyTokens.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Confidence Banner

/// Displays auto-categorization confidence level with contextual messaging.
private struct ConfidenceBanner: View {

    let text: String
    let category: TaxCategory
    let jurisdiction: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            let result = ReceiptCategorizer.categorize(text: text)

            HStack(spacing: SpacingTokens.xSmall) {
                AccessibleStatusIndicator(
                    color: confidenceColor(result.confidence),
                    icon: confidenceIcon(result.confidence),
                    label: confidenceAccessibilityLabel(result.confidence)
                )

                Text(confidenceMessage(result.confidence))
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            if result.confidence != .high {
                Text("Review the fields below and adjust as needed.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func confidenceIcon(_ confidence: ReceiptCategorizer.Confidence) -> String {
        switch confidence {
        case .high: "checkmark.circle.fill"
        case .medium: "exclamationmark.circle.fill"
        case .low: "questionmark.circle.fill"
        }
    }

    private func confidenceColor(_ confidence: ReceiptCategorizer.Confidence) -> Color {
        switch confidence {
        case .high: ColorTokens.positive
        case .medium: ColorTokens.warning
        case .low: ColorTokens.neutral
        }
    }

    private func confidenceMessage(_ confidence: ReceiptCategorizer.Confidence) -> String {
        switch confidence {
        case .high: "High confidence — category and jurisdiction auto-detected."
        case .medium: "Medium confidence — please verify the details below."
        case .low: "Low confidence — manual categorization recommended."
        }
    }

    private func confidenceAccessibilityLabel(_ confidence: ReceiptCategorizer.Confidence) -> String {
        switch confidence {
        case .high: "High confidence"
        case .medium: "Medium confidence"
        case .low: "Low confidence"
        }
    }
}

#Preview {
    ReceiptConfirmationView(viewModel: TaxVaultViewModel(services: .preview))
        .modelContainer(for: [TaxDocument.self, JurisdictionProfile.self], inMemory: true)
}
