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

    /// The app-wide interactive tint sourced from the AccentColor asset.
    ///
    /// Keep this aligned with App-level `.tint(...)` so prominent buttons,
    /// tab selection, and interactive controls share one canonical action color.
    static let actionTint = Color.accentColor

    /// Foreground color on top of action-tint filled controls.
    static let onActionTint = Color.white

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

    // MARK: - Tinted Fills

    /// The fill behind a tinted chip or badge whose foreground carries
    /// the same tint. Strengthens under Increase Contrast.
    static func tintedFill(_ color: Color, contrast: ColorSchemeContrast) -> Color {
        color.opacity(contrast == .increased ? 0.24 : 0.12)
    }

    /// The quieter fill for a large tinted panel or banner, where a
    /// chip-strength tint would overpower its content.
    static func tintedSurface(_ color: Color, contrast: ColorSchemeContrast) -> Color {
        color.opacity(contrast == .increased ? 0.2 : 0.08)
    }

    /// The outline drawn around tinted shapes under Increase Contrast,
    /// so their edges no longer depend on a faint fill.
    static let increasedContrastOutline = Color.primary.opacity(0.55)

    // MARK: - Selection States

    /// Selection background for list-like selectable rows.
    static func selectedRowBackground(for contrast: ColorSchemeContrast) -> Color {
        switch contrast {
        case .increased:
            return actionTint.opacity(0.16)
        default:
            return actionTint.opacity(0.08)
        }
    }

    /// Border color for selectable row outlines.
    static func selectableRowBorder(
        isSelected: Bool,
        contrast: ColorSchemeContrast
    ) -> Color {
        if isSelected {
            return actionTint
        }

        switch contrast {
        case .increased:
            return Color.secondary.opacity(0.6)
        default:
            return Color.secondary.opacity(0.2)
        }
    }

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

    /// Returns the SF Symbol icon for an FX markup value (Differentiate Without Color).
    /// - Parameter markup: The FX markup amount (positive = overpaid).
    static func fxMarkupIcon(for markup: Double) -> String {
        if markup <= 0 {
            return "checkmark.circle.fill"
        } else if markup < 1.0 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.octagon.fill"
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

    /// Returns the SF Symbol icon for a budget utilization fraction (Differentiate Without Color).
    /// - Parameter fraction: The spent fraction (0.0 to 1.0+).
    static func budgetIcon(for fraction: Double) -> String {
        if fraction < 0.8 {
            return "checkmark.circle.fill"
        } else if fraction < 1.0 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.octagon.fill"
        }
    }
}
