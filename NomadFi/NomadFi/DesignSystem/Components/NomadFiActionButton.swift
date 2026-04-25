// NomadFiActionButton.swift
// NomadFi
//
// Single, opinionated action-button primitive for the entire app.
// Bakes in `.labelStyle(.titleAndIcon)` so the SF Symbol next to
// the title always renders — across every control size, every
// Dynamic Type level, and every press / focus state.
//
// Why this primitive exists (incident learning):
//
//   SwiftUI's default label-style propagation collapses `Label`
//   content to icon-only or title-only depending on the
//   surrounding container, control size, and accessibility text
//   size. Inside a `Button` with `.borderedProminent`, that meant
//   our `Open Review` / `Open Archive` / `Capture decision` /
//   `Mark reviewed` buttons rendered title-only at rest and
//   only flashed the icon during the press animation. Visually
//   broken, accessibility-incoherent, and a recurring trap.
//
//   The fix is a single component that every action button in
//   the app routes through. The component:
//     • Always uses `Label(title:systemImage:)` — never a bare
//       `Text` — so the icon is always part of the layout.
//     • Always applies `.labelStyle(.titleAndIcon)` — the icon
//       cannot be hidden by the surrounding context.
//     • Picks the matching `ButtonStyle` from a small enum so
//       call sites cannot drift on visual treatment.
//     • Carries an explicit `accessibilityHint` parameter so the
//       VoiceOver hint is part of the API, not an afterthought.
//
//   The `NomadFiActionButtonStyleTests` suite pins the title-and-
//   icon contract so a future "convenience init" can't quietly
//   strip the modifier.
//
// HIG alignment:
//   • Labels with both a glyph and text scan faster, especially
//     under stress, in glance contexts, and at large Dynamic Type
//     sizes (per Apple's accessibility + buttons guidance).
//   • The three styles map to Apple's standard prominence ladder
//     (`.borderedProminent`, `.bordered`, `.borderless`) so the
//     primitive slots into existing system surfaces without
//     visual tax.

import SwiftUI

/// Visual prominence variant for `NomadFiActionButton`. Maps to
/// Apple's standard `ButtonStyle` ladder so the primitive feels
/// native everywhere it appears.
enum NomadFiActionButtonStyle: Sendable, Equatable, Hashable {

    /// Primary call-to-action — `.borderedProminent` filled tint.
    /// One per command module per Apple's HIG hierarchy guidance.
    case primary

    /// Secondary action — `.bordered` outline. Use alongside a
    /// primary button when the user has two reasonable choices.
    case secondary

    /// Tertiary, low-emphasis action — `.borderless` text-style.
    /// Use for "Cancel"-shaped affordances or list-row chevrons.
    case tertiary
}

/// The app's single labeled action-button primitive. Always
/// renders both the title and the SF Symbol. Routes its
/// accessibility hint through the API rather than the call site.
struct NomadFiActionButton: View {

    let title: String
    let systemImage: String
    var style: NomadFiActionButtonStyle = .primary
    var controlSize: ControlSize = .regular
    var role: ButtonRole? = nil
    /// Whether the label spans the full width of its container.
    /// Defaults to `true` so primary CTAs land as full-bleed
    /// command bars; secondary/tertiary action sites that prefer
    /// intrinsic sizing pass `false`.
    var fillsWidth: Bool = true
    var accessibilityHint: String? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            label
        }
        .modifier(StyleModifier(style: style))
        .controlSize(controlSize)
        .modifier(AccessibilityHintModifier(hint: accessibilityHint))
    }

    @ViewBuilder
    private var label: some View {
        if fillsWidth {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
        } else {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
    }
}

// MARK: - Style modifier

/// Applies the matching SwiftUI `ButtonStyle` for the requested
/// `NomadFiActionButtonStyle`. Kept as a `ViewModifier` rather
/// than a `switch` inside `body` so the build matrix stays small
/// and the call site is one line.
private struct StyleModifier: ViewModifier {

    let style: NomadFiActionButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content.buttonStyle(.borderedProminent)
        case .secondary:
            content.buttonStyle(.bordered)
        case .tertiary:
            content.buttonStyle(.borderless)
        }
    }
}

// MARK: - Accessibility-hint modifier

/// Conditional hint applier — `accessibilityHint(_:)` cannot
/// take an `Optional<String>`, so we route through a modifier
/// that no-ops on `nil` and applies the hint otherwise.
private struct AccessibilityHintModifier: ViewModifier {

    let hint: String?

    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

#Preview("Primary, secondary, tertiary") {
    VStack(spacing: SpacingTokens.medium) {
        NomadFiActionButton(
            title: "Open Review",
            systemImage: "checkmark.circle",
            style: .primary,
            accessibilityHint: "Switches Tax Vault to the Review surface.",
            action: {}
        )
        NomadFiActionButton(
            title: "Open Archive",
            systemImage: "tray.full",
            style: .secondary,
            action: {}
        )
        NomadFiActionButton(
            title: "Cancel",
            systemImage: "xmark",
            style: .tertiary,
            role: .cancel,
            fillsWidth: false,
            action: {}
        )
    }
    .padding(SpacingTokens.large)
}
