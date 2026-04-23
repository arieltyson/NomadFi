// TaxSuggestionsSection.swift
// NomadFi
//
// Review-queue section rendered at the top of `TaxVaultView`. Only
// appears when there's at least one pending suggestion; otherwise
// it's not in the list at all. Tapping a row opens the review
// sheet; the sheet owns all mutations.

import SwiftUI

struct TaxSuggestionsSection: View {

    let suggestions: [TaxCategorySuggestion]
    let onSelect: (TaxCategorySuggestion) -> Void

    var body: some View {
        Section {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    TaxSuggestionRow(suggestion: suggestion)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the review sheet for this suggestion.")
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Label("Suggestions to review", systemImage: "sparkles.rectangle.stack")
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(suggestions.count)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } footer: {
            Text("NomadFi surfaces transactions that may be tax-relevant. Review before including them in your tax records. NomadFi does not provide tax advice.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
