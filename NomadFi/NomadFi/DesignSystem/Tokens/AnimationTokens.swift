// AnimationTokens.swift
// NomadFi
//
// Shared animation curves and durations. All animations
// respect accessibilityReduceMotion automatically.

import SwiftUI

/// Animation tokens for consistent motion throughout NomadFi.
///
/// Every animation in the app should use one of these tokens
/// rather than defining inline animation parameters. All tokens
/// are designed to be paired with `withAnimation()` or the
/// `.animation()` modifier.
enum AnimationTokens {

    /// Quick response for interactive feedback (button taps, toggles).
    static let snappy: Animation = .snappy(duration: 0.2)

    /// Standard transition for most UI state changes.
    static let standard: Animation = .smooth(duration: 0.3)

    /// Deliberate transition for content appearing/disappearing.
    static let entrance: Animation = .spring(duration: 0.4, bounce: 0.15)

    /// Counting-up animation for numeric value changes (net worth, balances).
    static let numericCount: Animation = .smooth(duration: 0.6)

    /// Stagger delay for list item animations.
    /// - Parameter index: The item's position in the list.
    /// - Returns: A spring animation with a staggered delay.
    static func stagger(index: Int) -> Animation {
        .spring(duration: 0.35, bounce: 0.15)
            .delay(Double(index) * 0.05)
    }
}
