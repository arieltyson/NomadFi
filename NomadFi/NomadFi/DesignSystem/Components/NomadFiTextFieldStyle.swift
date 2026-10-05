// NomadFiTextFieldStyle.swift
// NomadFi
//
// Single, opinionated `TextFieldStyle` for every text input that
// lives on a custom surface. A solid field one step above the
// ``SurfaceCard`` it sits on, with a brand-tinted hairline.
//
// Why this primitive exists (incident learning):
//
//   The system `.roundedBorder` style bakes in a fixed fill that
//   reads as a hole punched in a card in dark mode. This style uses
//   the surface scale instead, so the field always reads as raised
//   chrome on its card.
//
// HIG alignment:
//   • Brand identity — the outline uses `ColorTokens.actionTint` at
//     a calm resting opacity, lifting to full opacity under Increase
//     Contrast.
//   • Layout / Dynamic Type — only the container chrome is
//     opinionated; the inner `TextField` scales exactly as the
//     system intends.
//
// When to use:
//
//   • `.textFieldStyle(.nomadFi)` for inputs on a `SurfaceCard`,
//     sheet bodies, and brief detail views.
//   • System `Form` rows already render fields correctly; do NOT
//     apply this style there.

import SwiftUI

/// `TextFieldStyle` that gives every NomadFi text input the same
/// solid rounded container, in every appearance.
struct NomadFiTextFieldStyle: TextFieldStyle {

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    /// Hairline stroke width. Kept here so a future high-contrast
    /// pass can lift this single constant rather than chasing
    /// magic numbers across the codebase.
    private static let strokeWidth: CGFloat = 1

    /// Resting opacity for the brand-tinted outline. Slightly
    /// muted so the field reads as branded without being shouty
    /// against a quiet card surface; lifts to fully opaque under
    /// `colorSchemeContrast == .increased` for inclusivity.
    private static let restingStrokeOpacity: Double = 0.55

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.xSmall)
            .background(
                ColorTokens.surfaceTertiary,
                in: .rect(cornerRadius: RadiusTokens.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: RadiusTokens.small,
                    style: .continuous
                )
                .strokeBorder(strokeColor, lineWidth: Self.strokeWidth)
            }
    }

    /// Border colour — uses the app's accent green
    /// (`ColorTokens.actionTint`) so every NomadFi-owned text
    /// field carries the brand identity at rest. Lifts to fully
    /// opaque under increased-contrast for inclusivity; otherwise
    /// muted slightly so the outline reads as branded chrome
    /// rather than a focus ring.
    private var strokeColor: Color {
        let opacity = colorSchemeContrast == .increased
            ? 1.0
            : Self.restingStrokeOpacity
        return ColorTokens.actionTint.opacity(opacity)
    }
}

// MARK: - Static lookup

extension TextFieldStyle where Self == NomadFiTextFieldStyle {

    /// The app-wide text-field style. Use as
    /// `.textFieldStyle(.nomadFi)` on every `TextField` that lives
    /// on a custom surface (e.g. inside a `SurfaceCard`). System
    /// `Form` rows already get the right treatment from SwiftUI —
    /// don't apply this there.
    static var nomadFi: NomadFiTextFieldStyle {
        NomadFiTextFieldStyle()
    }
}
