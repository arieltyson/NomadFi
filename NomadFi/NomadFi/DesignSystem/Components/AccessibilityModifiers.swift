// AccessibilityModifiers.swift
// NomadFi
//
// Shared accessibility primitives for consistent Reduce Motion and
// Differentiate Without Color behavior across the app.
//
// Translucency is deliberately absent: navigation bars, tab bars and
// sheets get Liquid Glass — and its Reduce Transparency fallback —
// from the system, and content sits on solid surfaces.

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
///     .reduceMotionAnimation(AnimationTokens.standard, value: balance)
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

    /// The dot grows with the caption text it sits beside.
    @ScaledMetric(relativeTo: .caption2) private var dotDiameter: CGFloat = SpacingTokens.xSmall

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
                .frame(width: dotDiameter, height: dotDiameter)
        }
        .accessibilityElement(children: .ignore)
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
}
