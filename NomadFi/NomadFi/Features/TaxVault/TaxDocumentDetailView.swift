// TaxDocumentDetailView.swift
// NomadFi
//
// Detail view for a single tax document showing the full receipt image,
// extracted data, tax category, and editing controls.

import SwiftData
import SwiftUI

/// Displays full details of a scanned tax document with editing controls.
///
/// Shows the receipt image, extracted merchant info, amount, category,
/// jurisdiction, and the raw OCR text. Users can edit fields and
/// toggle verification status.
struct TaxDocumentDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Bindable var document: TaxDocument

    @State private var isEditingCategory = false
    @FocusState private var isMerchantFocused: Bool

    var body: some View {
        List {
            receiptImageSection

            documentInfoSection

            categorySection

            ocrTextSection

            metadataSection
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDone($isMerchantFocused)
    }
}

// MARK: - Sections

private extension TaxDocumentDetailView {

    // MARK: Receipt Image

    /// Receipt image section using downsampled rendering.
    ///
    /// Caps the decoded image at 400×600pt (1200×1800px @3x) rather than
    /// loading the full-resolution camera image into memory.
    var receiptImageSection: some View {
        Section {
            if document.imageURL != nil {
                DownsampledImage(
                    url: document.imageURL,
                    size: CGSize(width: 400, height: 600),
                    contentMode: .fit
                )
                .clipShape(.rect(cornerRadius: RadiusTokens.medium, style: .continuous))
                .frame(maxHeight: 300)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(
                    top: SpacingTokens.xSmall,
                    leading: SpacingTokens.medium,
                    bottom: SpacingTokens.xSmall,
                    trailing: SpacingTokens.medium
                ))
            } else {
                imagePlaceholder
            }
        }
    }

    var imagePlaceholder: some View {
        ContentUnavailableView {
            Label("No Receipt Image", systemImage: "photo")
        } description: {
            Text("The original receipt image is not available.")
        }
        .frame(height: 200)
    }

    // MARK: Document Info

    var documentInfoSection: some View {
        Section("Document Details") {
            LabeledContent("Merchant") {
                TextField("Merchant name", text: $document.merchantName)
                    .multilineTextAlignment(.trailing)
                    .focused($isMerchantFocused)
                    .submitLabel(.done)
                    .onSubmit { isMerchantFocused = false }
            }

            LabeledContent("Amount") {
                Text(
                    document.amount,
                    format: .currency(code: document.currencyCode?.rawValue ?? "USD")
                )
                .bold()
            }

            LabeledContent("Currency") {
                Picker("Currency", selection: $document.currencyCodeRawValue) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text(code.displayName)
                            .tag(code.rawValue)
                    }
                }
                .labelsHidden()
            }

            LabeledContent("Date") {
                DatePicker(
                    "Document date",
                    selection: $document.documentDate,
                    displayedComponents: .date
                )
                .labelsHidden()
            }

            LabeledContent("Tax Year") {
                Text(String(document.taxYear))
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Jurisdiction") {
                Text(jurisdictionDisplay)
                    .foregroundStyle(.secondary)
            }

            Toggle("Verified", isOn: $document.isVerified)

            verificationStatusRow
        }
    }

    // MARK: Category

    var categorySection: some View {
        Section("Tax Category") {
            Picker("Category", selection: $document.taxCategoryRawValue) {
                ForEach(TaxCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.systemImage)
                        .tag(category.rawValue)
                }
            }
            .pickerStyle(.navigationLink)

            if let category = document.taxCategory {
                Label(category.displayName, systemImage: category.systemImage)
                    .font(TypographyTokens.body)
                    .foregroundStyle(ColorTokens.brandPrimary)
            }
        }
    }

    // MARK: OCR Text

    var ocrTextSection: some View {
        Section("Extracted Text") {
            if document.extractedText.isEmpty {
                Text("No text was extracted from this receipt.")
                    .foregroundStyle(.secondary)
                    .font(TypographyTokens.caption)
            } else {
                Text(document.extractedText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Metadata

    var metadataSection: some View {
        Section("Scan Info") {
            LabeledContent("Scanned") {
                Text(document.scannedAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
            }
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
        }
    }

    var verificationStatusRow: some View {
        let increasedContrast = colorSchemeContrast == .increased
        let statusColor = document.isVerified ? ColorTokens.positive : ColorTokens.warning
        let statusIcon = document.isVerified ? "checkmark.seal.fill" : "questionmark.circle.fill"
        let statusLabel = document.isVerified ? "Verified for export" : "Needs review before export"

        return HStack {
            Text("Verification Status")
                .foregroundStyle(.secondary)

            Spacer()

            Label(statusLabel, systemImage: statusIcon)
                .font(TypographyTokens.caption)
                .bold()
                .padding(.horizontal, SpacingTokens.xSmall)
                .padding(.vertical, SpacingTokens.xxSmall)
                .background(ColorTokens.tintedFill(statusColor, contrast: colorSchemeContrast))
                .foregroundStyle(increasedContrast ? .primary : statusColor)
                .overlay {
                    if increasedContrast {
                        Capsule()
                            .strokeBorder(statusColor, lineWidth: 1)
                    }
                }
                .clipShape(.capsule)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Helpers

private extension TaxDocumentDetailView {

    var jurisdictionDisplay: String {
        let code = document.jurisdiction
        guard !code.isEmpty else { return "Unknown" }
        return String.flagEmoji(for: code) + " " + code
    }

}

#Preview {
    NavigationStack {
        TaxDocumentDetailView(
            document: TaxDocument(
                merchantName: "Whole Foods Market",
                amount: 67.43,
                currencyCode: .usd,
                documentDate: .now,
                taxYear: 2026,
                jurisdiction: "US",
                taxCategory: .other,
                extractedText: "WHOLE FOODS MARKET\n1765 California St\nSan Francisco, CA 94109\n\nOrganic Bananas  2.49\nAlmond Milk      4.99\n\nTOTAL          67.43",
                isVerified: true
            )
        )
    }
    .modelContainer(for: TaxDocument.self, inMemory: true)
}
