// RadiusTokens.swift
// NomadFi
//
// Corner radius scale. Always paired with `style: .continuous`.

import SwiftUI

/// Corner radius tokens for NomadFi's design system.
///
/// Radii are their own scale rather than borrowed spacing values, so
/// tightening the grid never reshapes a card by accident.
///
/// ```swift
/// .background(ColorTokens.surfaceSecondary, in: .rect(cornerRadius: RadiusTokens.card, style: .continuous))
/// ```
enum RadiusTokens {

    /// 8pt — Text fields, inline chips, thumbnails.
    static let small: CGFloat = 8

    /// 12pt — Rows, inset panels, selectable options.
    static let medium: CGFloat = 12

    /// 16pt — Cards.
    static let card: CGFloat = 16
}
