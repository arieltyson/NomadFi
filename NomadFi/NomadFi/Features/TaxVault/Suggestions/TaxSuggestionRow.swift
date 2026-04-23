// TaxSuggestionRow.swift
// NomadFi
//
// Single-row renderer for the Tax Vault review queue. Read-only —
// tapping the row opens the review sheet via the parent. Uses
// project tokens and never implies the expense is deductible.

import SwiftUI

struct TaxSuggestionRow: View {

    let suggestion: TaxCategorySuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(suggestion.merchantName)
                        .font(TypographyTokens.body)
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)
                    Text(suggestion.transactionDate.formatted(.dateTime.year().month(.abbreviated).day()))
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: SpacingTokens.xSmall)
                Text(suggestion.amount, format: .currency(code: suggestion.currencyCode.rawValue))
                    .font(TypographyTokens.body)
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                Label {
                    Text("Suggested category: \(suggestion.proposedCategory.displayName)")
                        .font(TypographyTokens.caption)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: suggestion.proposedCategory.systemImage)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: SpacingTokens.xSmall)
                StatusBadge(
                    label: suggestion.confidence.displayLabel,
                    color: confidenceColor,
                    systemImage: suggestion.confidence.systemImage
                )
                .accessibilityLabel(suggestion.confidence.accessibilityLabel)
            }

            if !suggestion.reasonSummary.isEmpty {
                Text(suggestion.reasonSummary)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, SpacingTokens.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var confidenceColor: Color {
        switch suggestion.confidence {
        case .high: ColorTokens.positive
        case .medium: ColorTokens.warning
        case .low: ColorTokens.neutral
        }
    }

    private var accessibilitySummary: String {
        let amount = suggestion.amount.formatted(
            .currency(code: suggestion.currencyCode.rawValue)
        )
        let date = suggestion.transactionDate.formatted(
            .dateTime.year().month(.wide).day()
        )
        return "\(suggestion.merchantName), \(amount) on \(date). Suggested category: \(suggestion.proposedCategory.displayName). \(suggestion.confidence.accessibilityLabel)"
    }
}
