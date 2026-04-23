// TaxVaultReviewView.swift
// NomadFi
//
// Review is the "act on it" surface — primary scan action,
// tax-category suggestion queue, and a calm inline scan tip. No
// education content, no archive clutter. First-viewport clarity
// was the whole point of the Tax Vault IA refresh.

import PhotosUI
import SwiftData
import SwiftUI
import TipKit

struct TaxVaultReviewView: View {

    let suggestions: [TaxCategorySuggestion]
    let transactions: [Transaction]

    @Bindable var viewModel: TaxVaultViewModel
    @Bindable var suggestionReview: TaxSuggestionReviewViewModel

    private let scanTip = ScanReceiptTip()

    var body: some View {
        List {
            scanSection
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

    private var scanSection: some View {
        Section {
            scanCard
            TipView(scanTip)
                .tipBackground(ColorTokens.surfaceSecondary)
        } header: {
            Text("Add to Tax Vault")
        } footer: {
            Text("NomadFi reads the image on device. Nothing uploads.")
                .font(TypographyTokens.caption)
        }
    }

    private var scanCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: SpacingTokens.small) {
                TintedIconBadge(
                    systemImage: "doc.text.viewfinder",
                    tint: ColorTokens.brandPrimary,
                    size: .large
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("Scan a receipt")
                        .font(TypographyTokens.sectionHeader)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick a photo of your receipt. NomadFi reads it on device, suggests a category, and waits for you to confirm.")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    PhotosPicker(
                        selection: $viewModel.selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Choose photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, SpacingTokens.xxSmall)
                    .accessibilityHint("Opens your photo library so NomadFi can scan a receipt on device.")
                }
            }
        }
        .listRowInsets(EdgeInsets(
            top: SpacingTokens.xSmall,
            leading: SpacingTokens.medium,
            bottom: SpacingTokens.xSmall,
            trailing: SpacingTokens.medium
        ))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var noSuggestionsSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("No suggestions to review")
                        .font(TypographyTokens.body)
                    Text("NomadFi will surface tax-relevant transactions here when it sees them. Imports and manual entries both feed this queue.")
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
