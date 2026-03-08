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

    private let maxContentWidth: CGFloat = 620

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                headerSection

                mockPermissionSection

                footerSection
            }
            .frame(maxWidth: maxContentWidth)
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.top, SpacingTokens.xLarge)
            .padding(.bottom, SpacingTokens.large)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(ColorTokens.surfacePrimary.ignoresSafeArea())
        .task(id: viewModel.canShowAnimatedPrompt) {
            guard viewModel.canShowAnimatedPrompt, !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                borderGlowPhase = 1
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                arrowBounceOffset = 10
            }
        }
        .onAppear {
            viewModel.refreshAuthorizationStatus()
        }
        .onChange(of: viewModel.canShowAnimatedPrompt) { _, isVisible in
            if !isVisible {
                borderGlowPhase = 0
                arrowBounceOffset = 0
            }
        }
    }
}

// MARK: - Header

private extension LocationPermissionPrimingView {

    var headerSection: some View {
        VStack(spacing: SpacingTokens.small) {
            Text("Use location for better card recommendations.")
                .font(TypographyTokens.amountMedium)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("NomadFi only uses your current country on-device to suggest the lowest-fee payment card where you are.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mock Permission

private extension LocationPermissionPrimingView {

    var mockPermissionSection: some View {
        VStack(spacing: 0) {
            mockDialogContainer

            if viewModel.isNotDetermined {
                PermissionArrowIndicator(bounceOffset: arrowBounceOffset)
                    .accessibilityHidden(true)
            }
        }
    }

    var mockDialogContainer: some View {
        let borderColor = viewModel.isDeniedOrRestricted ? ColorTokens.warning : ColorTokens.actionTint

        return VStack(spacing: SpacingTokens.medium) {
            MockPermissionDialogContent(status: viewModel.authorizationStatus)
        }
        .padding(SpacingTokens.small)
        .background(ColorTokens.surfaceSecondary.opacity(0.35), in: .rect(cornerRadius: SpacingTokens.medium))
        .overlay {
            RoundedRectangle(cornerRadius: SpacingTokens.medium)
                .strokeBorder(
                    borderColor.opacity(0.45 + (borderGlowPhase * 0.4)),
                    lineWidth: 2.5
                )
                .shadow(
                    color: borderColor.opacity(0.25 + (borderGlowPhase * 0.25)),
                    radius: 16
                )
        }
        .reduceMotionAnimation(AnimationTokens.entrance, value: viewModel.authorizationStatus)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Location permission preview")
    }
}

private struct MockPermissionDialogContent: View {

    let status: CLAuthorizationStatus

    @ScaledMetric private var symbolSize: CGFloat = 42

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
        .padding(SpacingTokens.medium)
        .background(ColorTokens.surfacePrimary, in: .rect(cornerRadius: SpacingTokens.small))
    }

    var authorizedView: some View {
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
        .padding(.vertical, SpacingTokens.large)
    }

    var deniedView: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "location.slash.circle.fill")
                .font(.system(size: symbolSize))
                .foregroundStyle(ColorTokens.warning)
                .accessibilityHidden(true)

            Text("Location Access Not Enabled")
                .font(TypographyTokens.sectionHeader)
                .bold()

            Text("You can continue setup now and enable location later in iOS Settings.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.large)
    }

    var pendingView: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            HStack(spacing: SpacingTokens.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: SpacingTokens.small)
                        .fill(.linearGradient(
                            colors: [ColorTokens.actionTint.opacity(0.9), ColorTokens.brandSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 64, height: 64)

                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundStyle(ColorTokens.onActionTint)
                }
                .accessibilityHidden(true)

                Spacer(minLength: 0)
            }

            Text(#""NomadFi" Would Like to Use Your Location"#)
                .font(TypographyTokens.sectionHeader)
                .bold()
                .fixedSize(horizontal: false, vertical: true)

            Text("NomadFi detects your current country to recommend the lowest-fee payment card where you are.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            MockLocationPreviewMap()
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                MockPermissionButton(title: "Allow Once")
                MockPermissionButton(title: "Allow While Using App")
                MockPermissionButton(title: "Don’t Allow", isPrimary: false)
            }
            .accessibilityHidden(true)
        }
    }
}

private struct MockLocationPreviewMap: View {

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: SpacingTokens.medium)
                .fill(.linearGradient(
                    colors: [
                        ColorTokens.actionTint.opacity(0.28),
                        ColorTokens.brandSecondary.opacity(0.4),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .aspectRatio(1.75, contentMode: .fit)

            MapGridOverlay()
                .clipShape(.rect(cornerRadius: SpacingTokens.medium))
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

    var body: some View {
        Text(title)
            .font(TypographyTokens.sectionHeader)
            .bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.medium)
            .background(ColorTokens.surfaceTertiary, in: .rect(cornerRadius: SpacingTokens.medium))
            .foregroundStyle(isPrimary ? .primary : .secondary)
    }
}

private struct PermissionArrowIndicator: View {

    let bounceOffset: CGFloat

    @ScaledMetric private var arrowSize: CGFloat = 52

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
            .padding(.trailing, SpacingTokens.xLarge)
            .padding(.top, SpacingTokens.xSmall)
            .offset(y: -bounceOffset)
    }
}

// MARK: - Footer

private extension LocationPermissionPrimingView {

    @ViewBuilder
    var footerSection: some View {
        switch viewModel.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            VStack(spacing: SpacingTokens.small) {
                Button("Finish Setup", action: onFinishSetup)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
                    .controlSize(.large)
                    .tint(ColorTokens.actionTint)

                Text("You can enable location later from Settings to improve Active Card recommendations.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        default:
            VStack(spacing: SpacingTokens.small) {
                Button(
                    viewModel.isRequestingPermission ? "Waiting for iOS Permission…" : "Allow Location Access"
                ) {
                    viewModel.requestLocationPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(ColorTokens.actionTint)
                .disabled(viewModel.isRequestingPermission)
                .accessibilityHint("Requests location access so NomadFi can recommend the best card for your current country.")

                Button("Not Now", action: onSkipLocation)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
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
