// DashboardSilhouette.swift
// NomadFi
//
// A quiet, brand-green sketch of a dashboard for when there is no data.

import SwiftUI

/// A placeholder net-worth card: a redacted headline over a rising bar
/// chart in the brand colour. It suggests what the Dashboard becomes
/// without pretending to be real data, so it is hidden from VoiceOver.
struct DashboardSilhouette: View {

    /// Decorative bar heights, as fractions of the chart, rising left to
    /// right: a net worth that grows. Not data.
    static let trend: [Double] = [0.38, 0.52, 0.46, 0.64, 0.58, 0.8, 1]

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Global Net Worth")
                    .font(.subheadline)
                Text(verbatim: "$00,000.00")
                    .font(.title)
                    .bold()
            }
            .redacted(reason: .placeholder)
            .foregroundStyle(ColorTokens.brandPrimary.tertiary)

            DashboardSilhouetteBars(trend: Self.trend)
        }
        .padding(SpacingTokens.large)
        .frame(maxWidth: SizeTokens.emptyStateIllustrationMaxWidth)
        .background(
            ColorTokens.tintedSurface(ColorTokens.brandPrimary, contrast: contrast),
            in: .rect(cornerRadius: RadiusTokens.card)
        )
        .accessibilityHidden(true)
    }
}

/// The bars, which grow in one after another unless Reduce Motion is on.
private struct DashboardSilhouetteBars: View {

    let trend: [Double]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .title) private var chartHeight = SizeTokens.emptyStateChartHeight
    @State private var hasAppeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.xSmall) {
            ForEach(trend.enumerated(), id: \.offset) { index, fraction in
                RoundedRectangle(cornerRadius: RadiusTokens.small)
                    .fill(fill(isLatest: index == trend.count - 1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .scaleEffect(y: hasAppeared ? fraction : 0, anchor: .bottom)
                    .animation(
                        reduceMotion ? nil : AnimationTokens.entrance.delay(Double(index) * AnimationTokens.staggerStep),
                        value: hasAppeared
                    )
            }
        }
        .frame(height: chartHeight)
        .onAppear { hasAppeared = true }
    }

    /// The latest bar in the full brand colour; earlier ones as tints.
    private func fill(isLatest: Bool) -> some ShapeStyle {
        isLatest
            ? AnyShapeStyle(ColorTokens.brandPrimary.gradient)
            : AnyShapeStyle(ColorTokens.tintedFill(ColorTokens.brandPrimary, contrast: contrast).gradient)
    }
}

#Preview {
    DashboardSilhouette()
        .padding()
}
