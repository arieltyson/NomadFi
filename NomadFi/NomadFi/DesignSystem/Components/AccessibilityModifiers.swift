// AccessibilityModifiers.swift
// NomadFi
//
// Shared accessibility view modifiers for consistent reduce motion,
// reduce transparency, and Dynamic Type behavior across the app.

import SwiftUI

// MARK: - Reduce Motion Animation

/// A view modifier that conditionally applies animation based on
/// the user's Reduce Motion accessibility preference.
///
/// When Reduce Motion is enabled, the animation is replaced with `nil`
/// (instant transition), providing a comfortable experience for users
/// sensitive to motion.
///
/// ```swift
/// Text("Balance")
///     .modifier(ReduceMotionAnimation(value: balance))
/// ```
struct ReduceMotionAnimation<V: Equatable>: ViewModifier {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let animation: Animation
    let value: V

    init(animation: Animation = .default, value: V) {
        self.animation = animation
        self.value = value
    }

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Dynamic Type Layout

/// A container that automatically switches between horizontal and vertical
/// layout based on available space and Dynamic Type size.
///
/// At standard text sizes, content flows horizontally. At larger accessibility
/// sizes (AX1–AX5), content stacks vertically to prevent truncation.
///
/// ```swift
/// DynamicTypeLayout {
///     Text("Label")
///     Text("Value")
/// }
/// ```
struct DynamicTypeLayout<Content: View>: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(
        spacing: CGFloat = SpacingTokens.xSmall,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        } else {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - Glass Background

/// A view modifier that provides a glass material background with
/// automatic fallback for Reduce Transparency.
///
/// Uses `.ultraThinMaterial` when transparency is allowed, and falls
/// back to a solid secondary surface when Reduce Transparency is enabled.
struct GlassBackground: ViewModifier {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                ColorTokens.surfaceSecondary
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Accessible Status Indicator

/// A status indicator that communicates meaning through both color and shape,
/// supporting the "Differentiate Without Color" accessibility setting.
///
/// When Differentiate Without Color is enabled, adds an SF Symbol icon
/// alongside the color to ensure the status is understandable.
///
/// ```swift
/// AccessibleStatusIndicator(
///     color: ColorTokens.positive,
///     icon: "checkmark.circle.fill",
///     label: "Under budget"
/// )
/// ```
struct AccessibleStatusIndicator: View {

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let color: Color
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: SpacingTokens.xxSmall) {
            if differentiateWithoutColor {
                Image(systemName: icon)
                    .font(.caption2)
            }

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - View Extensions

extension View {

    /// Applies animation that respects the Reduce Motion accessibility setting.
    ///
    /// - Parameters:
    ///   - animation: The animation to apply when Reduce Motion is off.
    ///   - value: The value to animate when changed.
    func reduceMotionAnimation<V: Equatable>(
        _ animation: Animation = .default,
        value: V
    ) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: value))
    }

    /// Applies a glass material background that respects Reduce Transparency.
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}
