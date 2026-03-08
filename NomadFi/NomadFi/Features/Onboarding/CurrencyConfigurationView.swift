import SwiftUI

/// Onboarding step where users select their home (primary) currency.
///
/// The available currencies are derived from the jurisdictions selected
/// in the previous step. The home currency determines how global net worth
/// is displayed on the dashboard.
struct CurrencyConfigurationView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header

            currencyList

            Spacer()

            continueButton
        }
        .padding(SpacingTokens.large)
        .reduceMotionAnimation(AnimationTokens.standard, value: viewModel.homeCurrencyCode)
    }
}

// MARK: - Subviews

private struct CurrencyOption: View {

    let currency: CurrencyCode
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let increasedContrast = colorSchemeContrast == .increased

        Button(action: action) {
            HStack(spacing: SpacingTokens.small) {
                Text(currency.symbol)
                    .font(TypographyTokens.amountMedium)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(currency.rawValue)
                        .font(TypographyTokens.sectionHeader)

                    Text(currency.displayName)
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
            .clipShape(.rect(cornerRadius: SpacingTokens.small))
            .overlay(
                RoundedRectangle(cornerRadius: SpacingTokens.small)
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
        .accessibilityLabel("\(currency.displayName), \(currency.symbol)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Private Helpers

private extension CurrencyConfigurationView {

    var header: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            Text("What is your home currency?")
                .font(TypographyTokens.amountMedium)
                .bold()
                .multilineTextAlignment(.center)

            Text("Your global net worth will be displayed in this currency. You can change it later in Settings.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    var currencyList: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.xSmall) {
                ForEach(viewModel.availableCurrencies) { currency in
                    CurrencyOption(
                        currency: currency,
                        isSelected: viewModel.homeCurrencyCode == currency,
                        action: { viewModel.homeCurrencyCode = currency }
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    var continueButton: some View {
        Button("Continue", action: viewModel.advance)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
}

#Preview {
    let viewModel = OnboardingViewModel()
    viewModel.selectedJurisdictions = [
        JurisdictionInfo.supported[0],
        JurisdictionInfo.supported[1],
        JurisdictionInfo.supported[2],
    ]
    return CurrencyConfigurationView(viewModel: viewModel)
}
