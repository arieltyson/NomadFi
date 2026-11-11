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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hapticConductor) private var conductor
    /// Counts flips so each new choice spins the coin again.
    @State private var flips = 0

    var body: some View {
        let increasedContrast = colorSchemeContrast == .increased

        Button(action: choose) {
            HStack(spacing: SpacingTokens.small) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(currency.symbol)
                        .font(TypographyTokens.amountMedium)
                        .bold()
                        .keyframeAnimator(initialValue: 0.0, trigger: flips) { symbol, angle in
                            symbol.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
                        } keyframes: { _ in
                            CoinFlipKeyframes.track
                        }

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
        .accessibilityLabel("\(currency.displayName), \(currency.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Choosing a currency tosses its sign like a coin.
    private func choose() {
        guard !isSelected else { return }
        action()
        conductor?.play(.coinSettle)
        if !reduceMotion { flips += 1 }
    }
}

/// The coin's spin, keyed to ``CoinCadence``: the sign is edge on at each
/// haptic tap (every half turn), each half turn quicker to slow, and it
/// settles face on.
private enum CoinFlipKeyframes {
    static var track: some Keyframes<Double> {
        KeyframeTrack {
            LinearKeyframe(90, duration: 0)
            LinearKeyframe(270, duration: CoinCadence.edges[1] - CoinCadence.edges[0])
            LinearKeyframe(450, duration: CoinCadence.edges[2] - CoinCadence.edges[1])
            LinearKeyframe(630, duration: CoinCadence.edges[3] - CoinCadence.edges[2])
            LinearKeyframe(810, duration: CoinCadence.edges[4] - CoinCadence.edges[3])
            LinearKeyframe(990, duration: CoinCadence.edges[5] - CoinCadence.edges[4])
            LinearKeyframe(1080, duration: CoinCadence.total - CoinCadence.edges[5])
        }
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
            .accessibilityHint("Continues to account setup.")
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
