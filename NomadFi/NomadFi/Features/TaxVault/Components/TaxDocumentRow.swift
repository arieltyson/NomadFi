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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        NavigationLink(value: document) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    HStack(spacing: SpacingTokens.small) {
                        receiptThumbnail
                        documentInfo
                    }

                    amountColumn
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: SpacingTokens.small) {
                    receiptThumbnail

                    documentInfo

                    Spacer()

                    amountColumn
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Subviews

private extension TaxDocumentRow {

    /// Receipt thumbnail using memory-efficient downsampling.
    ///
    /// Uses ``DownsampledImage`` instead of `AsyncImage` to avoid
    /// loading multi-megabyte receipt images at full resolution
    /// for a 44×44pt display. See ``ImageDownsampler`` for details.
    var receiptThumbnail: some View {
        DownsampledImage(
            url: document.imageURL,
            size: CGSize(width: 44, height: 44)
        )
        .clipShape(.rect(cornerRadius: RadiusTokens.small, style: .continuous))
        .accessibilityHidden(true)
    }

    var documentInfo: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(document.merchantName)
                .font(TypographyTokens.sectionHeader)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: SpacingTokens.xxSmall) {
                if let category = document.taxCategory {
                    Label(category.displayName, systemImage: category.systemImage)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(document.documentDate, format: .dateTime.month(.abbreviated).day().year())
                .font(TypographyTokens.caption)
                .foregroundStyle(.tertiary)
        }
    }

    var amountColumn: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: SpacingTokens.xxSmall) {
            Text(
                document.amount,
                format: .currency(code: document.currencyCode?.rawValue ?? "USD")
            )
            .font(TypographyTokens.amountSmall)
            .bold()

            verificationBadge
        }
    }

    var verificationBadge: some View {
        let increasedContrast = colorSchemeContrast == .increased

        return Label(
            document.isVerified ? "Verified" : "Needs Review",
            systemImage: document.isVerified ? "checkmark.seal.fill" : "questionmark.circle.fill"
        )
        .font(.caption2)
        .bold()
        .padding(.horizontal, SpacingTokens.xxSmall)
        .padding(.vertical, SpacingTokens.xxxSmall)
        .background(
            ColorTokens.tintedFill(
                document.isVerified ? ColorTokens.positive : ColorTokens.warning,
                contrast: colorSchemeContrast
            )
        )
        .foregroundStyle(increasedContrast ? .primary : (document.isVerified ? ColorTokens.positive : ColorTokens.warning))
        .overlay {
            if increasedContrast {
                Capsule()
                    .strokeBorder(
                        document.isVerified ? ColorTokens.positive : ColorTokens.warning,
                        lineWidth: 1
                    )
            }
        }
        .clipShape(.capsule)
        .accessibilityLabel(document.isVerified ? "Verified" : "Needs review")
    }

    var accessibilityDescription: String {
        let currency = document.currencyCode?.rawValue ?? "USD"
        let amount = document.amount.formatted(.currency(code: currency))
        let category = document.taxCategory?.displayName ?? "Other"
        let date = document.documentDate.formatted(date: .abbreviated, time: .omitted)
        let verificationStatus = document.isVerified ? "verified" : "needs review"
        return "\(document.merchantName), \(amount), \(category), \(date), \(verificationStatus)"
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
