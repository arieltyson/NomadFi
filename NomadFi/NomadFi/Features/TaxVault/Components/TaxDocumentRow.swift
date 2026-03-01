// TaxDocumentRow.swift
// NomadFi
//
// A single row displaying a tax document's thumbnail, merchant,
// amount, date, and category in the Tax Vault list.

import SwiftData
import SwiftUI

/// Displays a tax document as a compact list row with receipt thumbnail,
/// merchant name, amount, date, and tax category.
///
/// Tapping the row navigates to ``TaxDocumentDetailView`` via the
/// parent `NavigationStack`'s `navigationDestination(for:)`.
struct TaxDocumentRow: View {

    let document: TaxDocument

    var body: some View {
        NavigationLink(value: document) {
            HStack(spacing: SpacingTokens.small) {
                receiptThumbnail

                documentInfo

                Spacer()

                amountColumn
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Subviews

private extension TaxDocumentRow {

    var receiptThumbnail: some View {
        Group {
            if let imageURL = document.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.rect(cornerRadius: SpacingTokens.xSmall))
        .accessibilityHidden(true)
    }

    var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(ColorTokens.surfaceTertiary)
            .overlay {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }

    var documentInfo: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(document.merchantName)
                .font(TypographyTokens.sectionHeader)
                .lineLimit(1)

            HStack(spacing: SpacingTokens.xxSmall) {
                if let category = document.taxCategory {
                    Label(category.displayName, systemImage: category.systemImage)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(document.documentDate, format: .dateTime.month(.abbreviated).day().year())
                .font(TypographyTokens.caption)
                .foregroundStyle(.tertiary)
        }
    }

    var amountColumn: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.xxSmall) {
            Text(
                document.amount,
                format: .currency(code: document.currencyCode?.rawValue ?? "USD")
            )
            .font(TypographyTokens.amountSmall)
            .bold()

            if document.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.positive)
                    .accessibilityLabel("Verified")
            }
        }
    }

    var accessibilityDescription: String {
        let currency = document.currencyCode?.rawValue ?? "USD"
        let amount = document.amount.formatted(.currency(code: currency))
        let category = document.taxCategory?.displayName ?? "Other"
        let date = document.documentDate.formatted(date: .abbreviated, time: .omitted)
        let verified = document.isVerified ? ", verified" : ""
        return "\(document.merchantName), \(amount), \(category), \(date)\(verified)"
    }
}

#Preview {
    NavigationStack {
        List {
            TaxDocumentRow(
                document: TaxDocument(
                    merchantName: "Whole Foods Market",
                    amount: 67.43,
                    currencyCode: .usd,
                    documentDate: .now,
                    taxYear: 2026,
                    jurisdiction: "US",
                    taxCategory: .other,
                    isVerified: true
                )
            )

            TaxDocumentRow(
                document: TaxDocument(
                    merchantName: "University of San Francisco",
                    amount: 15_000,
                    currencyCode: .usd,
                    documentDate: .now,
                    taxYear: 2026,
                    jurisdiction: "US",
                    taxCategory: .tuition,
                    isVerified: false
                )
            )
        }
    }
    .modelContainer(for: TaxDocument.self, inMemory: true)
}
