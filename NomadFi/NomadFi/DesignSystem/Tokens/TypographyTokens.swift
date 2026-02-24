// TypographyTokens.swift
// NomadFi
//
// Typography scale built entirely on Dynamic Type.
// Never use hard-coded font sizes; these tokens scale
// automatically with the user's accessibility settings.

import SwiftUI

/// Typography tokens providing semantic text styles for NomadFi.
///
/// Every token maps to a Dynamic Type style, ensuring the app
/// remains fully readable at all accessibility text sizes (including AX5).
enum TypographyTokens {

    /// Large monetary amounts - global net worth headline.
    static let amountLarge: Font = .largeTitle

    /// Medium monetary amounts - account balances.
    static let amountMedium: Font = .title2

    /// Small monetary amounts - transaction rows, exchange rates.
    static let amountSmall: Font = .body

    /// Section headers - jurisdiction group headers, card titles.
    static let sectionHeader: Font = .headline

    /// Body text - descriptions, insight explanations.
    static let body: Font = .body

    /// Secondary text - timestamps, metadata, captions.
    static let caption: Font = .caption

    /// Footnote text - legal disclaimers, "last updated" timestamps.
    static let footnote: Font = .footnote
}
