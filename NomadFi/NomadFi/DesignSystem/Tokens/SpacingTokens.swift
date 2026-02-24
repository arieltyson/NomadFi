// SpacingTokens.swift
// NomadFi
//
// A consistent spacing grid based on a 4pt base unit.
// Use these tokens for all padding, margins, and stack spacing
// to maintain visual rhythm throughout the app.

import SwiftUI

/// Spacing tokens based on a 4pt grid system.
///
/// Consistent spacing creates visual rhythm and professional polish.
/// These values align with Apple's HIG spacing recommendations.
enum SpacingTokens {

    /// 4pt - Minimal spacing between tightly related elements.
    static let xxSmall: CGFloat = 4

    /// 8pt - Compact spacing within card content.
    static let xSmall: CGFloat = 8

    /// 12pt - Default spacing between related elements.
    static let small: CGFloat = 12

    /// 16pt - Standard padding and stack spacing.
    static let medium: CGFloat = 16

    /// 24pt - Spacing between distinct sections.
    static let large: CGFloat = 24

    /// 32pt - Major section separators.
    static let xLarge: CGFloat = 32

    /// 48pt - Top-level layout spacing.
    static let xxLarge: CGFloat = 48
}
