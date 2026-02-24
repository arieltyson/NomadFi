// ColorTokens.swift
// NomadFi
//
// Semantic color tokens that adapt to light/dark/high-contrast
// automatically. Never use hard-coded hex values in views; always
// reference these tokens instead.

import SwiftUI

/// Semantic color tokens for NomadFi's design system.
///
/// All colors are defined semantically (by purpose, not by hue)
/// so they adapt correctly across light mode, dark mode,
/// increased contrast, and Differentiate Without Color settings.
enum ColorTokens {

    // MARK: - Brand

    /// The primary brand color - deep teal. Used for primary actions and key UI accents.
    static let brandPrimary = Color("BrandPrimary", bundle: .main)

    /// A lighter teal variant for secondary elements and hover states.
    static let brandSecondary = Color("BrandSecondary", bundle: .main)

    // MARK: - Semantic

    /// Positive financial indicator - gains, savings, under-budget.
    static let positive = Color.green

    /// Warning financial indicator - approaching budget limit, slight FX markup.
    static let warning = Color.orange

    /// Negative financial indicator - losses, over-budget, significant FX markup.
    static let negative = Color.red

    /// Neutral/informational - no financial implication.
    static let neutral = Color.secondary

    // MARK: - Surface

    /// Primary background for cards and elevated surfaces.
    static let surfacePrimary = Color(.systemBackground)

    /// Secondary background for grouped content areas.
    static let surfaceSecondary = Color(.secondarySystemBackground)

    /// Tertiary background for nested groupings.
    static let surfaceTertiary = Color(.tertiarySystemBackground)

    // MARK: - FX Markup Indicators

    /// Returns the appropriate color for an FX markup value.
    /// - Parameter markup: The FX markup amount (positive = overpaid).
    static func fxMarkupColor(for markup: Double) -> Color {
        if markup <= 0 {
            return positive
        } else if markup < 1.0 {
            return warning
        } else {
            return negative
        }
    }

    /// Returns the appropriate color for a budget utilization fraction.
    /// - Parameter fraction: The spent fraction (0.0 to 1.0+).
    static func budgetColor(for fraction: Double) -> Color {
        if fraction < 0.8 {
            return positive
        } else if fraction < 1.0 {
            return warning
        } else {
            return negative
        }
    }
}
