import CoreLocation
import SwiftUI

/// A deterministic onboarding surface that primes location permission
/// before showing the system prompt.
struct LocationPermissionPrimingView: View {

    let onFinishSetup: () -> Void
    let onSkipLocation: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = LocationPermissionPrimingViewModel()
    @State private var borderGlowPhase: CGFloat = 0
    @State private var arrowBounceOffset: CGFloat = 0

    private let maxContentWidth: CGFloat = 560

    var body: some View {
        ZStack {
            ColorTokens.surfacePrimary
                .ignoresSafeArea()

            ViewThatFits(in: .vertical) {
                contentContainer(isCompact: false)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.top, SpacingTokens.large)
                    .padding(.bottom, SpacingTokens.medium)

                contentContainer(isCompact: true)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.top, SpacingTokens.medium)
                    .padding(.bottom, SpacingTokens.small)

                ScrollView {
                    contentContainer(isCompact: false)
                        .padding(.horizontal, SpacingTokens.medium)
                        .padding(.top, SpacingTokens.large)
                        .padding(.bottom, SpacingTokens.medium)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task(id: viewModel.canShowAnimatedPrompt) {
            guard viewModel.canShowAnimatedPrompt, !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                borderGlowPhase = 1
            }

            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                arrowBounceOffset = 8
            }
        }
        .onAppear {
            viewModel.refreshAuthorizationStatus()
        }
        .onChange(of: viewModel.canShowAnimatedPrompt) { _, canAnimate in
            if !canAnimate {
                borderGlowPhase = 0
                arrowBounceOffset = 0
            }
        }
    }
}

private extension LocationPermissionPrimingView {

    func contentContainer(isCompact: Bool) -> some View {
        LocationPermissionPrimingContent(
            viewModel: viewModel,
            borderGlowPhase: borderGlowPhase,
            arrowBounceOffset: arrowBounceOffset,
            isCompact: isCompact,
            maxContentWidth: maxContentWidth,
            onFinishSetup: onFinishSetup,
            onSkipLocation: onSkipLocation
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct LocationPermissionPrimingContent: View {

    @Bindable var viewModel: LocationPermissionPrimingViewModel

    let borderGlowPhase: CGFloat
    let arrowBounceOffset: CGFloat
    let isCompact: Bool
    let maxContentWidth: CGFloat
    let onFinishSetup: () -> Void
    let onSkipLocation: () -> Void

    var body: some View {
        VStack(spacing: isCompact ? SpacingTokens.medium : SpacingTokens.large) {
            LocationPermissionHeader(isCompact: isCompact)

            mockPermissionSection

            LocationPermissionFooter(
                viewModel: viewModel,
                isCompact: isCompact,
                onFinishSetup: onFinishSetup,
                onSkipLocation: onSkipLocation
            )
        }
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var mockPermissionSection: some View {
        VStack(spacing: 0) {
            mockDialogContainer

            if viewModel.isNotDetermined {
                PermissionArrowIndicator(
                    bounceOffset: arrowBounceOffset,
                    isCompact: isCompact
                )
                .accessibilityHidden(true)
            }
        }
    }

    private var mockDialogContainer: some View {
        let borderColor = viewModel.isDeniedOrRestricted ? ColorTokens.warning : ColorTokens.actionTint

        return MockPermissionDialogContent(
            status: viewModel.authorizationStatus,
            isCompact: isCompact
        )
        .padding(isCompact ? SpacingTokens.xSmall : SpacingTokens.small)
        .background(
            ColorTokens.surfaceSecondary.opacity(isCompact ? 0.28 : 0.35),
            in: .rect(cornerRadius: RadiusTokens.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(
                    .linearGradient(
                        colors: [
                            borderColor.opacity(0.50 + borderGlowPhase * 0.35),
                            borderColor.opacity(0.26 + borderGlowPhase * 0.18),
                            borderColor.opacity(0.50 + borderGlowPhase * 0.35),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .shadow(
                    color: borderColor.opacity(0.34 + borderGlowPhase * 0.24),
                    radius: isCompact ? 11 : 14
                )
        }
        .reduceMotionAnimation(AnimationTokens.entrance, value: viewModel.authorizationStatus)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Location permission preview")
    }
}

private struct LocationPermissionHeader: View {

    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? SpacingTokens.xSmall : SpacingTokens.small) {
            Text("Connect to Location, Securely.")
                .font(isCompact ? .title3 : .title2)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("To recommend your best card where you are, NomadFi needs location permission.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MockPermissionDialogContent: View {

    let status: CLAuthorizationStatus
    let isCompact: Bool

    @ScaledMetric private var symbolSize: CGFloat = 40

    var body: some View {
        Group {
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                authorizedView
            } else if status == .denied || status == .restricted {
                deniedView
            } else {
                pendingView
            }
        }
        .padding(isCompact ? SpacingTokens.small : SpacingTokens.medium)
        .background(ColorTokens.surfacePrimary, in: .rect(cornerRadius: RadiusTokens.medium, style: .continuous))
    }

    private var authorizedView: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: symbolSize))
                .foregroundStyle(ColorTokens.positive)
                .accessibilityHidden(true)

            Text("Location Access Enabled")
                .font(TypographyTokens.sectionHeader)
                .bold()

            Text("Active Card can now recommend the best account for your current country.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? SpacingTokens.small : SpacingTokens.medium)
    }

    private var deniedView: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "location.slash.circle.fill")
                .font(.system(size: symbolSize))
                .foregroundStyle(ColorTokens.warning)
                .accessibilityHidden(true)

            Text("Location Access Not Enabled")
                .font(TypographyTokens.sectionHeader)
                .bold()

            Text("You can finish setup now and enable location later in iOS Settings.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? SpacingTokens.small : SpacingTokens.medium)
    }

    private var pendingView: some View {
        VStack(alignment: .leading, spacing: isCompact ? SpacingTokens.small : SpacingTokens.medium) {
            HStack(spacing: SpacingTokens.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.medium, style: .continuous)
                        .fill(
                            .linearGradient(
                                colors: [ColorTokens.actionTint.opacity(0.9), ColorTokens.brandSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isCompact ? 56 : 62, height: isCompact ? 56 : 62)

                    Image(systemName: "location.fill")
                        .font(isCompact ? .title3 : .title2)
                        .foregroundStyle(ColorTokens.onActionTint)
                }
                .accessibilityHidden(true)

                Spacer(minLength: 0)
            }

            Text("Allow \u{201C}NomadFi\u{201D} to use your location?")
                .font(TypographyTokens.amountMedium)
                .bold()
                .fixedSize(horizontal: false, vertical: true)

            Text("NomadFi detects your current country to recommend the lowest-fee payment card for where you are.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            MockLocationPreviewMap(isCompact: isCompact)
                .accessibilityHidden(true)

            VStack(spacing: isCompact ? SpacingTokens.xSmall : SpacingTokens.small) {
                MockPermissionButton(title: "Allow Once", isCompact: isCompact)
                MockPermissionButton(title: "Allow While Using App", isCompact: isCompact)
                MockPermissionButton(title: "Don\u{2019}t Allow", isPrimary: false, isCompact: isCompact)
            }
            .accessibilityHidden(true)
        }
    }
}

private struct MockLocationPreviewMap: View {

    let isCompact: Bool

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(
                    .linearGradient(
                        colors: [
                            ColorTokens.actionTint.opacity(0.26),
                            ColorTokens.brandSecondary.opacity(0.37),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MapGridOverlay()
                .clipShape(.rect(cornerRadius: RadiusTokens.card, style: .continuous))
                .allowsHitTesting(false)

            Text("Precise: On")
                .font(TypographyTokens.caption)
                .bold()
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.xxSmall)
                .background(Color.black.opacity(colorSchemeContrast == .increased ? 0.72 : 0.58))
                .foregroundStyle(.white)
                .clipShape(.capsule)
                .padding(SpacingTokens.small)
        }
        .aspectRatio(isCompact ? 2.25 : 2.05, contentMode: .fit)
        .frame(maxHeight: isCompact ? 148 : 170)
    }
}

private struct MapGridOverlay: View {

    var body: some View {
        Canvas { context, size in
            let lineColor = Color.white.opacity(0.16)
            let horizontalStep = max(size.height / 5, 20)
            let verticalStep = max(size.width / 6, 28)

            var horizontalLines = Path()
            var y: CGFloat = horizontalStep * 0.7
            while y < size.height {
                horizontalLines.move(to: CGPoint(x: 0, y: y))
                horizontalLines.addLine(to: CGPoint(x: size.width, y: y + 14))
                y += horizontalStep
            }

            var verticalLines = Path()
            var x: CGFloat = verticalStep * 0.6
            while x < size.width {
                verticalLines.move(to: CGPoint(x: x, y: 0))
                verticalLines.addLine(to: CGPoint(x: x - 14, y: size.height))
                x += verticalStep
            }

            context.stroke(horizontalLines, with: .color(lineColor), lineWidth: 1)
            context.stroke(verticalLines, with: .color(lineColor), lineWidth: 1)

            let markerRect = CGRect(
                x: (size.width * 0.52) - 11,
                y: (size.height * 0.58) - 11,
                width: 22,
                height: 22
            )
            context.fill(
                Path(ellipseIn: markerRect),
                with: .color(ColorTokens.actionTint)
            )
            context.stroke(
                Path(ellipseIn: markerRect.insetBy(dx: -5, dy: -5)),
                with: .color(Color.white.opacity(0.35)),
                lineWidth: 2
            )
        }
    }
}

private struct MockPermissionButton: View {

    let title: String
    var isPrimary: Bool = true
    let isCompact: Bool

    var body: some View {
        Text(title)
            .font(TypographyTokens.sectionHeader)
            .bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? SpacingTokens.small : SpacingTokens.medium)
            .background(ColorTokens.surfaceTertiary, in: .rect(cornerRadius: RadiusTokens.card, style: .continuous))
            .foregroundStyle(isPrimary ? .primary : .secondary)
    }
}

private struct PermissionArrowIndicator: View {

    let bounceOffset: CGFloat
    let isCompact: Bool

    @ScaledMetric private var arrowSize: CGFloat = 46

    var body: some View {
        Image(systemName: "arrow.turn.right.up")
            .font(.system(size: arrowSize))
            .bold()
            .foregroundStyle(
                .linearGradient(
                    colors: [ColorTokens.brandSecondary, ColorTokens.actionTint],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, isCompact ? SpacingTokens.large : SpacingTokens.xLarge)
            .padding(.top, isCompact ? SpacingTokens.xxSmall : SpacingTokens.xSmall)
            .offset(y: -bounceOffset)
    }
}

private struct LocationPermissionFooter: View {

    @Bindable var viewModel: LocationPermissionPrimingViewModel

    let isCompact: Bool
    let onFinishSetup: () -> Void
    let onSkipLocation: () -> Void

    var body: some View {
        switch viewModel.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            VStack(spacing: SpacingTokens.small) {
                Button("Finish Setup", action: onFinishSetup)
                    .buttonStyle(.borderedProminent)
                    .controlSize(isCompact ? .regular : .large)
                    .tint(ColorTokens.actionTint)

                Text("You can change this anytime in iOS Settings.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        case .denied, .restricted:
            VStack(spacing: SpacingTokens.small) {
                Button("Continue Without Location", action: onSkipLocation)
                    .buttonStyle(.borderedProminent)
                    .controlSize(isCompact ? .regular : .large)
                    .tint(ColorTokens.actionTint)

                Text("You can enable location later from Settings to improve Active Card recommendations.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        default:
            VStack(spacing: SpacingTokens.small) {
                Button(
                    viewModel.isRequestingPermission ? "Waiting for iOS Permission\u{2026}" : "Allow Location Access"
                ) {
                    viewModel.requestLocationPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(isCompact ? .regular : .large)
                .tint(ColorTokens.actionTint)
                .disabled(viewModel.isRequestingPermission)
                .accessibilityHint("Requests location access so NomadFi can recommend the best card for your current country.")

                Button("Not Now", action: onSkipLocation)
                    .buttonStyle(.bordered)
                    .controlSize(isCompact ? .regular : .large)
                    .accessibilityHint("Finishes setup and lets you enable location later.")
            }
        }
    }
}

#Preview {
    LocationPermissionPrimingView(
        onFinishSetup: {},
        onSkipLocation: {}
    )
}
