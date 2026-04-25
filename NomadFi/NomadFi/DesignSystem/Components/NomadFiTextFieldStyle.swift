// NomadFiTextFieldStyle.swift
// NomadFi
//
// Single, opinionated `TextFieldStyle` for every text input across
// the app. Wraps SwiftUI's `TextField` content in a Material-filled
// rounded container that adapts to light, dark, increased-contrast,
// and Reduce Transparency settings — the same surface language the
// rest of the design system already uses for `GlassCard`.
//
// Why this primitive exists (incident learning):
//
//   The system `.roundedBorder` `TextFieldStyle` collapses to a
//   flat black-on-black rectangle in dark mode when nested inside
//   a custom translucent surface (`GlassCard`). The system style
//   bakes in a fixed solid fill that doesn't blend with the
//   surrounding material; the user sees a hole punched in the
//   card. The fix is a single shared style that mirrors the
//   card's surface vocabulary (Material in a Shape + a hairline
//   stroke from the existing `ColorTokens.selectableRowBorder`
//   helper, with a solid fallback when the user has Reduce
//   Transparency enabled).
//
// HIG alignment:
//   • Materials and translucency — uses `.thinMaterial` so the
//     field reads as a slightly elevated surface within a
//     translucent card, matching the `GlassCard` aesthetic.
//   • Brand identity — the outline uses `ColorTokens.actionTint`
//     (the app's accent green) at a calm resting opacity so every
//     NomadFi-owned text field reads as branded chrome rather
//     than a generic system control.
//   • Inclusivity — falls back to `ColorTokens.surfaceTertiary`
//     when Reduce Transparency is on; lifts the outline to full
//     opacity under increased-contrast so the brand stroke stays
//     readable for users who turned that setting on.
//   • Layout / Dynamic Type — only the *container chrome* is
//     opinionated; the inner `TextField` is unchanged, so the
//     text scales with Dynamic Type exactly as the system intends.
//
// When to use:
//
//   • Use `.textFieldStyle(.nomadFi)` for every NomadFi text
//     input that lives on a custom surface (`GlassCard`, sheet
//     bodies, brief detail views).
//   • System `Form` rows already render fields with the right
//     adaptive treatment; do NOT apply this style there. The
//     primitive is for non-`Form` surfaces.

import SwiftUI

/// `TextFieldStyle` that gives every NomadFi text input the same
/// Material-backed rounded container, regardless of light/dark
/// mode or the surrounding card's surface treatment.
struct NomadFiTextFieldStyle: TextFieldStyle {

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

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
            .background {
                background
            }
            .clipShape(.rect(cornerRadius: SpacingTokens.xSmall, style: .continuous))
            .overlay {
                RoundedRectangle(
                    cornerRadius: SpacingTokens.xSmall,
                    style: .continuous
                )
                .strokeBorder(strokeColor, lineWidth: Self.strokeWidth)
            }
    }

    // MARK: - Surface

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            // Solid fallback — same semantic as `GlassCard`'s
            // Reduce Transparency path. `surfaceTertiary` reads as
            // a subtle elevation against the card's
            // `surfaceSecondary`-equivalent material.
            ColorTokens.surfaceTertiary
        } else {
            // Material in a Shape, per the iOS 26 SwiftUI rule.
            Rectangle().fill(.thinMaterial)
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
    /// on a custom surface (e.g. inside a `GlassCard`). System
    /// `Form` rows already get the right treatment from SwiftUI —
    /// don't apply this there.
    static var nomadFi: NomadFiTextFieldStyle {
        NomadFiTextFieldStyle()
    }
}
