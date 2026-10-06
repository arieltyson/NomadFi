// TaxVaultReviewView.swift
// NomadFi
//
// Review is the "act on it" surface: the tax-category suggestion
// queue. Adding a receipt is the toolbar's +, so the page opens
// straight onto what needs a decision.

import SwiftData
import SwiftUI

struct TaxVaultReviewView: View {

    let suggestions: [TaxCategorySuggestion]
    let transactions: [Transaction]

    @Bindable var viewModel: TaxVaultViewModel
    @Bindable var suggestionReview: TaxSuggestionReviewViewModel

    var body: some View {
        List {
            if !suggestions.isEmpty {
                TaxSuggestionsSection(
                    suggestions: suggestions,
                    onSelect: { suggestionReview.select($0) }
                )
            } else {
                noSuggestionsSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
    }

    // MARK: - Sections

    private var noSuggestionsSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("No suggestions to review")
                        .font(TypographyTokens.body)
                    Text(
                        "NomadFi will surface tax-relevant transactions here when it sees them. Imports and manual entries both feed this queue."
                    )
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(ColorTokens.positive)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("Suggestions to review")
        }
    }
}
