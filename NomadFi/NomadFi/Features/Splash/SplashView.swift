import SwiftUI

/// An animated splash screen that bridges the system launch screen
/// into the app's first content.
///
/// Shows the NomadFi brand identity — globe icon, app name, and tagline —
/// with a staggered entrance animation, then gracefully fades out to reveal
/// the onboarding flow or main dashboard beneath.
///
/// - Matches the system launch screen background for a seamless cold-start transition.
/// - Respects `accessibilityReduceMotion`: skips animation and dismisses quickly.
/// - VoiceOver announces the brand once, then focus moves to content.
struct SplashView: View {

    @Binding var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showIcon = false
    @State private var showText = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.medium) {
                brandIcon

                brandText
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("NomadFi. Wealth without borders.")
        }
        .task { await runSplashSequence() }
    }
}

// MARK: - Subviews

private extension SplashView {

    var brandIcon: some View {
        Image(systemName: "globe.americas.fill")
            .font(.system(size: 72))
            .foregroundStyle(ColorTokens.brandPrimary.gradient)
            .scaleEffect(showIcon ? 1.0 : 0.85)
            .opacity(showIcon ? 1 : 0)
    }

    var brandText: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            Text("NomadFi")
                .font(TypographyTokens.amountLarge)
                .bold()

            Text("Wealth without borders")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .opacity(showText ? 1 : 0)
        .offset(y: showText ? 0 : 8)
    }
}

// MARK: - Animation Sequence

private extension SplashView {

    func runSplashSequence() async {
        if reduceMotion {
            showIcon = true
            showText = true
            try? await Task.sleep(for: .seconds(0.8))
            isActive = false
            return
        }

        // Phase 1: Globe scales in
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation(.smooth(duration: 0.5)) {
            showIcon = true
        }

        // Phase 2: Text fades in
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.smooth(duration: 0.4)) {
            showText = true
        }

        // Phase 3: Hold, then dismiss
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.smooth(duration: 0.4)) {
            isActive = false
        }
    }
}

#Preview {
    SplashView(isActive: .constant(true))
}
