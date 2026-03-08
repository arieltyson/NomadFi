import SwiftUI

/// Horizontally scrollable filter chips for transaction categories and jurisdictions.
///
/// Allows multi-select for categories and single-select for jurisdiction.
/// Active filters are visually distinguished with the brand color.
struct TransactionFilterChips: View {

    @Bindable var viewModel: LedgerViewModel
    let jurisdictions: [JurisdictionProfile]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: SpacingTokens.xSmall) {
                jurisdictionChips

                Divider()
                    .frame(height: 24)

                categoryChips

                if viewModel.hasActiveFilters {
                    clearButton
                }
            }
            .padding(.horizontal, SpacingTokens.medium)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Subviews

private struct FilterChip: View {

    let label: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let increasedContrast = colorSchemeContrast == .increased
        let showSelectedIndicator = isSelected && (differentiateWithoutColor || increasedContrast)
        let foregroundColor: Color = isSelected
            ? (increasedContrast ? .primary : ColorTokens.onActionTint)
            : .primary

        Button(action: action) {
            HStack(spacing: SpacingTokens.xxSmall) {
                if showSelectedIndicator {
                    Image(systemName: "checkmark")
                        .imageScale(.small)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }

                Text(label)
                    .font(TypographyTokens.caption)
            }
            .padding(.horizontal, SpacingTokens.xSmall)
            .padding(.vertical, SpacingTokens.xxSmall + 2)
            .foregroundStyle(foregroundColor)
            .background(
                isSelected
                    ? ColorTokens.actionTint
                    : ColorTokens.surfaceSecondary
            )
            .clipShape(.capsule)
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? (increasedContrast ? Color.primary.opacity(0.7) : Color.clear)
                            : Color.secondary.opacity(increasedContrast ? 0.6 : 0.25),
                        lineWidth: increasedContrast ? 2 : 1
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(label) filter")
        .accessibilityHint(isSelected ? "Double tap to remove filter" : "Double tap to apply filter")
    }
}

// MARK: - Private Helpers

private extension TransactionFilterChips {

    var jurisdictionChips: some View {
        ForEach(jurisdictions, id: \.countryCode) { profile in
            FilterChip(
                label: profile.countryCode,
                systemImage: nil,
                isSelected: viewModel.selectedJurisdiction == profile.countryCode,
                action: {
                    if viewModel.selectedJurisdiction == profile.countryCode {
                        viewModel.selectedJurisdiction = nil
                    } else {
                        viewModel.selectedJurisdiction = profile.countryCode
                    }
                }
            )
        }
    }

    var categoryChips: some View {
        ForEach(TransactionCategory.allCases) { category in
            FilterChip(
                label: category.displayName,
                systemImage: category.systemImage,
                isSelected: viewModel.selectedCategories.contains(category),
                action: { viewModel.toggleCategory(category) }
            )
        }
    }

    var clearButton: some View {
        Button("Clear", systemImage: "xmark.circle.fill", action: viewModel.clearFilters)
            .font(TypographyTokens.caption)
            .foregroundStyle(ColorTokens.negative)
    }
}

#Preview {
    TransactionFilterChips(
        viewModel: LedgerViewModel(),
        jurisdictions: [
            JurisdictionProfile(countryCode: "US", countryName: "United States", currencyCode: .usd),
            JurisdictionProfile(countryCode: "CA", countryName: "Canada", currencyCode: .cad),
        ]
    )
}
