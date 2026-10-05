// TintedIconBadge.swift
// NomadFi
//
// Design-system primitive: a small, tinted rounded-square chip
// wrapping an SF Symbol. Visually aligned with Apple's Settings-app
// hub icons so any NomadFi surface that needs glance-level "this is
// category X" identity — Settings hub rows today, Dashboard filter
// rows or onboarding cards tomorrow — speaks the same visual
// language.
//
// Why it lives here:
// • Coherence with the rest of the design system (`SurfaceCard`,
//   `StatusBadge`, `CurrencyText`): every reusable visual idiom has
//   a single home.
// • Tokens only: uses `ColorTokens`, `SpacingTokens`, and Apple's
//   Dynamic Type scaling — no ad-hoc colours or hard-coded padding.
// • Accessibility defaults: always decorative; callers must carry
//   the semantic label on the surrounding row so VoiceOver never
//   announces "image" over every list cell.

import SwiftUI

/// Rounded-square SF-symbol chip used to give a row / card a
/// single-glance category identity, styled to match Apple's Settings
/// hub iconography.
///
/// The chip is purely visual. The enclosing view is responsible for
/// the accessibility label — this keeps VoiceOver quiet where a glyph
/// alone would otherwise speak nothing useful.
struct TintedIconBadge: View {

    /// Size variants tuned to common NomadFi contexts. Each value is a
    /// base point size that scales with Dynamic Type via
    /// `@ScaledMetric`, so the chip grows with the surrounding text
    /// at accessibility sizes instead of getting lost beside it.
    enum Size {

        /// Inline with caption-scale text (badges nested in rows).
        case small

        /// Default — matches Apple Settings' hub icon scale.
        case medium

        /// Prominent — useful when the chip is the focal point of a card.
        case large

        var basePoint: CGFloat {
            switch self {
            case .small: 22
            case .medium: 29
            case .large: 36
            }
        }

        var baseCornerRadius: CGFloat {
            switch self {
            case .small: 5
            case .medium: 7
            case .large: 9
            }
        }

        var symbolFont: Font {
            switch self {
            case .small: .footnote.weight(.semibold)
            case .medium: .callout.weight(.semibold)
            case .large: .title3.weight(.semibold)
            }
        }
    }

    let systemImage: String
    var tint: Color = ColorTokens.brandPrimary
    var size: Size = .medium

    /// Dynamic Type scale factor relative to `.body`. Multiplying the
    /// size variant's base dimensions by this factor keeps the chip in
    /// proportion with the surrounding text at every content-size
    /// category, without needing per-variant `@ScaledMetric` storage.
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale: CGFloat = 1
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let point = size.basePoint * dynamicTypeScale
        let cornerRadius = size.baseCornerRadius * dynamicTypeScale

        Image(systemName: systemImage)
            .font(size.symbolFont)
            .foregroundStyle(ColorTokens.onActionTint)
            .frame(width: point, height: point)
            .background(
                tint.gradient,
                in: .rect(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                if colorSchemeContrast == .increased {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(ColorTokens.increasedContrastOutline, lineWidth: 1)
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    List {
        Section("Hub iconography") {
            Label {
                Text("Financial Setup")
            } icon: {
                TintedIconBadge(
                    systemImage: "globe.americas.fill",
                    tint: ColorTokens.brandPrimary
                )
            }

            Label {
                Text("Notifications")
            } icon: {
                TintedIconBadge(
                    systemImage: "bell.badge.fill",
                    tint: ColorTokens.warning
                )
            }

            Label {
                Text("Privacy & Security")
            } icon: {
                TintedIconBadge(
                    systemImage: "lock.shield.fill",
                    tint: ColorTokens.positive
                )
            }
        }

        Section("Sizing") {
            HStack(spacing: SpacingTokens.small) {
                TintedIconBadge(systemImage: "star.fill", tint: ColorTokens.brandPrimary, size: .small)
                TintedIconBadge(systemImage: "star.fill", tint: ColorTokens.brandPrimary, size: .medium)
                TintedIconBadge(systemImage: "star.fill", tint: ColorTokens.brandPrimary, size: .large)
            }
        }
    }
}
