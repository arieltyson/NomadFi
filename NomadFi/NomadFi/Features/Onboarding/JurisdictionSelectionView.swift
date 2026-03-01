import SwiftUI

/// Onboarding step where users select the countries where their money lives.
///
/// Requires a minimum of two jurisdictions before proceeding.
/// Each selection triggers haptic feedback and is announced via VoiceOver.
struct JurisdictionSelectionView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header

            jurisdictionGrid

            Spacer()

            footer
        }
        .padding(SpacingTokens.large)
        .reduceMotionAnimation(AnimationTokens.standard, value: viewModel.selectedJurisdictions)
    }
}

// MARK: - Subviews

private struct JurisdictionButton: View {

    let jurisdiction: JurisdictionInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.small) {
                Text(jurisdiction.flag)
                    .font(.title2)

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(jurisdiction.name)
                        .font(TypographyTokens.sectionHeader)

                    Text(jurisdiction.currencyCode.displayName)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? ColorTokens.brandPrimary : Color(.tertiaryLabel))
            }
            .padding(SpacingTokens.medium)
            .background(isSelected ? ColorTokens.brandPrimary.opacity(0.08) : Color.clear)
            .clipShape(.rect(cornerRadius: SpacingTokens.small))
            .overlay(
                RoundedRectangle(cornerRadius: SpacingTokens.small)
                    .strokeBorder(
                        isSelected ? ColorTokens.brandPrimary : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(jurisdiction.flag) \(jurisdiction.name), \(jurisdiction.currencyCode.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
    }
}

// MARK: - Private Helpers

private extension JurisdictionSelectionView {

    var header: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            Text("Where does your money live?")
                .font(TypographyTokens.amountMedium)
                .bold()
                .multilineTextAlignment(.center)

            Text("Select at least two countries where you have financial accounts.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    var jurisdictionGrid: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.xSmall) {
                ForEach(JurisdictionInfo.supported) { jurisdiction in
                    JurisdictionButton(
                        jurisdiction: jurisdiction,
                        isSelected: viewModel.isSelected(jurisdiction),
                        action: { viewModel.toggleJurisdiction(jurisdiction) }
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    var footer: some View {
        VStack(spacing: SpacingTokens.small) {
            if !viewModel.canProceedFromJurisdictions {
                Text("Select at least \(2 - viewModel.selectedJurisdictions.count) more")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Continue", action: viewModel.advance)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canProceedFromJurisdictions)
        }
    }
}

#Preview {
    JurisdictionSelectionView(viewModel: OnboardingViewModel())
}
