// AnimationTokens.swift
// NomadFi
//
// Shared animation curves and durations.

import SwiftUI

/// Animation tokens for consistent motion throughout NomadFi.
///
/// Every animation in the app should use one of these tokens
/// rather than defining inline animation parameters. Tokens do not
/// check Reduce Motion themselves: apply them through
/// `.reduceMotionAnimation(_:value:)`, or pass `nil` to
/// `withAnimation` when `accessibilityReduceMotion` is on.
enum AnimationTokens {

    /// Quick response for interactive feedback (button taps, toggles).
    static let snappy: Animation = .snappy(duration: 0.2)

    /// Standard transition for most UI state changes.
    static let standard: Animation = .smooth(duration: 0.3)

    /// Deliberate transition for content appearing/disappearing.
    static let entrance: Animation = .spring(duration: 0.4, bounce: 0.15)

    /// Counting-up animation for numeric value changes (net worth, balances).
    static let numericCount: Animation = .smooth(duration: 0.6)

    /// Delay between items that enter one after another.
    static let staggerStep: Double = 0.05
}
