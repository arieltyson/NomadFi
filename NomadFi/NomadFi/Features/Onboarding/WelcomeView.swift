import SwiftUI

/// The first onboarding screen presenting NomadFi's value proposition.
///
/// It arrives in beats rather than all at once: the globe drifts down and
/// lands, then each headline line follows, then the details. The
/// ``HapticMotif/arrival`` score is played against the same
/// ``ArrivalCadence``, so every beat is felt as it is seen. With Reduce
/// Motion everything is simply present, without haptics.
struct WelcomeView: View {

    let onGetStarted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hapticConductor) private var conductor
    @State private var stage: WelcomeStage = .waiting

    var body: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            Spacer()

            WelcomeGlobe(hasLanded: stage >= .globe)

            WelcomeHeadline(stage: stage)

            WelcomeDetails(isVisible: stage >= .details)

            Spacer()

            Button("Get Started", action: onGetStarted)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(ColorTokens.actionTint)
                .accessibilityHint("Begins setting up your NomadFi profile")
                .opacity(stage >= .details ? 1 : 0)
        }
        .padding(SpacingTokens.large)
        .task { await reveal() }
    }

    /// Steps through the beats in time with the arrival haptics.
    private func reveal() async {
        guard stage == .waiting else { return }
        guard !reduceMotion else {
            stage = .details
            return
        }
        conductor?.play(.arrival)
        withAnimation(.spring(duration: ArrivalCadence.globeLands, bounce: 0.3)) { stage = .globe }
        await advance(to: .firstLine, at: ArrivalCadence.firstLine, after: 0)
        await advance(to: .secondLine, at: ArrivalCadence.secondLine, after: ArrivalCadence.firstLine)
        await advance(to: .details, at: ArrivalCadence.details, after: ArrivalCadence.secondLine)
    }

    private func advance(to next: WelcomeStage, at time: TimeInterval, after previous: TimeInterval) async {
        try? await Task.sleep(for: .seconds(time - previous))
        withAnimation(AnimationTokens.entrance) { stage = next }
    }
}

/// The beats of the welcome screen's arrival, in order.
enum WelcomeStage: Int, Comparable {
    case waiting, globe, firstLine, secondLine, details

    static func < (lhs: WelcomeStage, rhs: WelcomeStage) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Subviews

/// The globe, drifting down from above until it lands.
private struct WelcomeGlobe: View {

    let hasLanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "globe.americas.fill")
            .font(TypographyTokens.amountLarge)
            .foregroundStyle(ColorTokens.brandPrimary.gradient)
            .symbolEffect(.breathe, options: .repeating, isActive: hasLanded && !reduceMotion)
            .scaleEffect(hasLanded ? 1 : 0.6)
            .offset(y: hasLanded ? 0 : -SpacingTokens.xxLarge)
            .opacity(hasLanded ? 1 : 0)
            .accessibilityHidden(true)
    }
}

/// The two-line headline, each line arriving on its own beat.
private struct WelcomeHeadline: View {

    let stage: WelcomeStage

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            Text("Your money crosses borders.")
                .font(TypographyTokens.amountMedium)
                .bold()
                .arrival(isVisible: stage >= .firstLine)

            Text("Now it has one home.")
                .font(TypographyTokens.amountLarge)
                .bold()
                .foregroundStyle(ColorTokens.brandPrimary)
                .arrival(isVisible: stage >= .secondLine)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// What NomadFi does and why it matters, in plain words.
private struct WelcomeDetails: View {

    let isVisible: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            Text("NomadFi brings the money you keep in different countries into one place, so you can spot hidden fees, stay ready for tax time and pay with the right card wherever you are.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.medium)

            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                WelcomeReasonRow(icon: "lock.shield.fill", color: ColorTokens.positive,
                                 text: "Private by design, with no tracking.")
                WelcomeReasonRow(icon: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90", color: ColorTokens.warning,
                                 text: "International students lose thousands to hidden exchange fees.")
                WelcomeReasonRow(icon: "globe", color: ColorTokens.brandPrimary,
                                 text: "NomadFi shows where your money goes, in every country.")
            }
            .padding(SpacingTokens.medium)
            .background(ColorTokens.surfaceSecondary, in: .rect(cornerRadius: RadiusTokens.medium, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .arrival(isVisible: isVisible)
    }
}

private struct WelcomeReasonRow: View {

    let icon: String
    let color: Color
    let text: String

    @ScaledMetric(relativeTo: .caption) private var iconWidth = SpacingTokens.large

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: iconWidth)
                .accessibilityHidden(true)

            Text(text)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    /// Fades and lifts content into place when its beat arrives, and keeps
    /// VoiceOver from reading it before then.
    func arrival(isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : SpacingTokens.small)
            .accessibilityHidden(!isVisible)
    }
}

#Preview {
    WelcomeView { }
        .environment(\.hapticConductor, HapticConductor())
}
