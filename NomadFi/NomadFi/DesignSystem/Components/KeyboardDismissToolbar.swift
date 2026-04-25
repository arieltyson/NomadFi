// KeyboardDismissToolbar.swift
// NomadFi
//
// Custom keyboard accessory that renders a trailing "Done" button
// above the software keyboard. Built on `safeAreaInset` rather
// than SwiftUI's `ToolbarItemGroup(placement: .keyboard)` because
// the SwiftUI toolbar mechanism silently de-registers the keyboard
// item on subsequent focus changes — the user sees the Done
// button on the first field tap and then loses it for every tap
// after, which leaves them stranded on a `.decimalPad` keyboard
// with no way to dismiss it.
//
// Why `safeAreaInset` is the right primitive (incident learning):
//
//   • SwiftUI's `.toolbar { ToolbarItemGroup(placement: .keyboard) {} }`
//     loses its registration when the focused field identity
//     changes inside a custom `TextFieldStyle`, when the toolbar
//     is composed alongside navigation items, or when the host
//     view is presented as a sheet inside a `NavigationStack`.
//     Two separate community-documented SwiftUI bugs feed into
//     the same symptom — Apple's iOS 26 keyboard-toolbar
//     placement only re-registers reliably for the *first* focus.
//   • `safeAreaInset(edge: .bottom)` sits in our own view
//     hierarchy, so we control when the bar appears, what it
//     looks like, and what it does. The bar is bound to the
//     same `@FocusState` the fields use; whenever any field is
//     focused the bar is visible, every time, without exception.
//   • `Material` in a `Shape` (`.bar` ShapeStyle inside a
//     `Rectangle()`) gives the same translucent strip Apple uses
//     for its own keyboard accessories, so the result blends
//     naturally above any `.decimalPad`, `.numberPad`, or text
//     keyboard.
//
// HIG references:
//   • Keyboards — https://developer.apple.com/design/human-interface-guidelines/keyboards
//   • Materials — https://developer.apple.com/design/human-interface-guidelines/materials

import SwiftUI

/// The visible "Done" affordance that floats above the software
/// keyboard. Rendered by ``View/keyboardDoneAccessory(focused:)``;
/// not intended to be instantiated directly at call sites.
///
/// Visual language (iOS 26 Liquid Glass):
///   • Deliberately *no* full-width material strip behind the
///     button. iOS 26's design language moves away from imposed
///     toolbar chrome and toward floating controls that carry
///     their own glass treatment — the capsule itself provides
///     all the visual weight the bar needs.
///   • The trailing-aligned `KeyboardDoneCapsuleButton` is a
///     brand-tinted glass capsule that reads unambiguously as a
///     tap target against the parent surface above the keyboard.
///   • A 44pt minimum tap target is preserved through the
///     button's intrinsic padding plus the surrounding HStack
///     padding; both grow with Dynamic Type because the inner
///     `Text` uses `TypographyTokens.body`.
struct KeyboardDoneAccessoryBar: View {

    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            KeyboardDoneCapsuleButton(action: action)
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.xSmall)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Done capsule button

/// Solid brand-tinted capsule used as the keyboard accessory's
/// only affordance. Lives in its own struct so the visual
/// treatment (filled `actionTint` capsule + `onActionTint` bold
/// label) stays a single source of truth and the parent bar
/// doesn't break the "no view computed properties" rule.
///
/// Why a solid filled capsule instead of a tinted-glass one:
/// the bar floats above the keyboard with *no* container chrome
/// behind it, so the affordance has to carry all of its own
/// visual weight. A subtly-tinted glass capsule reads as
/// secondary chrome against the keyboard's blur; a solid
/// `actionTint` capsule reads unambiguously as the primary
/// action — same prominence ladder `NomadFiActionButton.primary`
/// uses elsewhere in the app, just adapted to a capsule shape
/// for the keyboard-accessory context.
private struct KeyboardDoneCapsuleButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(TypographyTokens.body)
                .bold()
                .foregroundStyle(ColorTokens.onActionTint)
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.xxSmall)
                .background {
                    Capsule(style: .continuous)
                        .fill(ColorTokens.actionTint)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
        .accessibilityHint("Dismisses the keyboard.")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Modifiers

/// Generic over the focus value type so the same modifier works
/// for every screen's `@FocusState` enum without ceremony.
private struct KeyboardDoneAccessoryModifier<Focus: Hashable>: ViewModifier {

    @FocusState.Binding var focused: Focus?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if focused != nil {
                    KeyboardDoneAccessoryBar { focused = nil }
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.snappy, value: focused != nil)
    }
}

/// Bool-valued variant for screens with a single field bound to
/// a `@FocusState<Bool>` rather than an optional enum.
private struct KeyboardDoneAccessoryBoolModifier: ViewModifier {

    @FocusState.Binding var focused: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if focused {
                    KeyboardDoneAccessoryBar { focused = false }
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.snappy, value: focused)
    }
}

extension View {

    /// Adds a "Done" keyboard accessory bar that's visible
    /// whenever any field bound to `focused` is the active focus.
    /// Use on every screen that contains a `.decimalPad` /
    /// `.numberPad` field — those keyboards have no Return key
    /// and the user has no other way to dismiss them.
    ///
    /// ```swift
    /// @FocusState private var focusedField: Field?
    ///
    /// Form { ... }
    ///     .keyboardDoneAccessory(focused: $focusedField)
    /// ```
    ///
    /// Why this exists instead of
    /// `ToolbarItemGroup(placement: .keyboard)`:
    /// SwiftUI's keyboard toolbar placement silently fails to
    /// re-register on subsequent focus changes inside sheets and
    /// alongside other toolbar items. This `safeAreaInset`-based
    /// accessory bypasses that mechanism entirely — the bar lives
    /// in our own view hierarchy and is bound to the same
    /// `@FocusState` the fields use, so it's always visible
    /// whenever any field is focused.
    ///
    /// - Parameter focused: The screen's `@FocusState` binding.
    func keyboardDoneAccessory<Focus: Hashable>(
        focused: FocusState<Focus?>.Binding
    ) -> some View {
        modifier(KeyboardDoneAccessoryModifier(focused: focused))
    }

    /// Bool-valued overload for screens with a single field bound
    /// to a `@FocusState<Bool>` rather than an optional enum. Same
    /// semantics — the bar appears whenever `focused` is `true`,
    /// disappears whenever it's `false`.
    func keyboardDoneAccessory(
        focused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(KeyboardDoneAccessoryBoolModifier(focused: focused))
    }
}
