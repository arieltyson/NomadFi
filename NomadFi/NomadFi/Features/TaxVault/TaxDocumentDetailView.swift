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
    @Bindable var document: TaxDocument

    @State private var isEditingCategory = false

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
    }
}

// MARK: - Sections

private extension TaxDocumentDetailView {

    // MARK: Receipt Image

    var receiptImageSection: some View {
        Section {
            if let imageURL = document.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: SpacingTokens.small))
                    default:
                        imagePlaceholder
                    }
                }
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
