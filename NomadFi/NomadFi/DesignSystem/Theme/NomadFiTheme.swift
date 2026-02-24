// NomadFiTheme.swift
// NomadFi
//
// A centralized theme providing convenience access to all design tokens.
// Injected into the SwiftUI environment for consistent theming.

import SwiftUI

/// The centralized theme for NomadFi, providing access to all design tokens.
///
/// Use `NomadFiTheme` as the single entry point for colors, typography,
/// spacing, and animation values throughout the app.
enum NomadFiTheme {

    /// Color tokens.
    typealias Colors = ColorTokens

    /// Typography tokens.
    typealias Typography = TypographyTokens

    /// Spacing tokens.
    typealias Spacing = SpacingTokens

    /// Animation tokens.
    typealias Animation = AnimationTokens
}
