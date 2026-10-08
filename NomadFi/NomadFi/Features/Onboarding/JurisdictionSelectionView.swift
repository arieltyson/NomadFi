import SwiftUI

/// Onboarding step where users select the countries where their money lives.
///
/// Requires at least one jurisdiction before proceeding.
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

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let increasedContrast = colorSchemeContrast == .increased

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
                    .foregroundStyle(isSelected ? ColorTokens.actionTint : Color(.tertiaryLabel))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SpacingTokens.medium)
            .background(
                isSelected
                    ? ColorTokens.selectedRowBackground(for: colorSchemeContrast)
                    : Color.clear
            )
            .clipShape(.rect(cornerRadius: RadiusTokens.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.medium, style: .continuous)
                    .strokeBorder(
                        ColorTokens.selectableRowBorder(
                            isSelected: isSelected,
                            contrast: colorSchemeContrast
                        ),
                        lineWidth: isSelected ? (increasedContrast ? 3 : 2) : (increasedContrast ? 2 : 1)
                    )
            )
            .contentShape(.rect)
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

            Text("Select every country where you have financial accounts.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("NomadFi uses your jurisdictions to detect FX fees, optimize card usage, and organize tax documents by country.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, SpacingTokens.xxSmall)
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
                Text("Select at least one country")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Continue", action: viewModel.advance)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canProceedFromJurisdictions)
                .accessibilityHint(
                    viewModel.canProceedFromJurisdictions
                        ? "Continues to the next step."
                        : "Select at least one jurisdiction to continue."
                )
        }
    }
}

#Preview {
    JurisdictionSelectionView(viewModel: OnboardingViewModel())
}
