import SwiftUI

/// The first onboarding screen presenting NomadFi's value proposition.
///
/// Designed for a full-bleed, emotionally resonant first impression.
/// Every element has VoiceOver support and respects Reduce Motion.
struct WelcomeView: View {

    let onGetStarted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            Spacer()

            globeIllustration

            headline

            description

            whyItMatters

            Spacer()

            getStartedButton
        }
        .padding(SpacingTokens.large)
        .onAppear { hasAppeared = true }
    }
}

// MARK: - Subviews

private struct WhyItMattersRow: View {

    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(text)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GlobeIllustration: View {

    let isAnimating: Bool
    let reduceMotion: Bool

    var body: some View {
        Image(systemName: "globe.americas.fill")
            .font(.system(size: 80))
            .foregroundStyle(ColorTokens.brandPrimary.gradient)
            .symbolEffect(.breathe, options: .repeating, isActive: isAnimating && !reduceMotion)
            .accessibilityHidden(true)
    }
}

private struct Headline: View {

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            Text("Your money lives in three countries.")
                .font(TypographyTokens.amountMedium)
                .bold()
                .multilineTextAlignment(.center)

            Text("Now it has one home.")
                .font(TypographyTokens.amountLarge)
                .bold()
                .foregroundStyle(ColorTokens.brandPrimary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Private Helpers

private extension WelcomeView {

    var globeIllustration: some View {
        GlobeIllustration(isAnimating: hasAppeared, reduceMotion: reduceMotion)
    }

    var headline: some View {
        Headline()
    }

    var description: some View {
        Text("NomadFi unifies your international finances into a single dashboard \u{2014} eliminating hidden FX fees, automating tax compliance, and optimizing every cross-border payment.")
            .font(TypographyTokens.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.medium)
    }

    var whyItMatters: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            WhyItMattersRow(
                icon: "lock.shield.fill",
                color: ColorTokens.positive,
                text: "On-device only. Zero tracking."
            )

            WhyItMattersRow(
                icon: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90",
                color: ColorTokens.warning,
                text: "International students lose thousands to hidden FX fees."
            )

            WhyItMattersRow(
                icon: "globe",
                color: ColorTokens.brandPrimary,
                text: "NomadFi makes cross-border money visible."
            )
        }
        .padding(SpacingTokens.medium)
        .glassBackground()
        .clipShape(.rect(cornerRadius: SpacingTokens.small))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NomadFi protects your financial privacy on-device, helps international students recover hidden FX fees, and makes cross-border money visible")
    }

    var getStartedButton: some View {
        Button("Get Started", action: onGetStarted)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Begins setting up your NomadFi profile")
    }
}

#Preview {
    WelcomeView { }
}
