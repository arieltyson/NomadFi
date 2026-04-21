// KeyboardDismissToolbar.swift
// NomadFi
//
// A small, SwiftUI-native helper that gives any view containing text
// fields a standard keyboard toolbar with a trailing Done button.
//
// HIG: https://developer.apple.com/design/human-interface-guidelines/keyboards
// Keyboard placement: https://developer.apple.com/documentation/SwiftUI/ToolbarItemPlacement/keyboard
//
// Why this exists:
// • `.decimalPad` and `.numberPad` keyboards do not expose a Return
//   key, so there is no built-in way for the user to dismiss them.
// • Every NomadFi form that accepts numeric input must offer an
//   explicit, visible dismissal affordance — no UIKit hacks, no
//   background tap gestures.

import SwiftUI

/// Attaches a keyboard accessory toolbar with a trailing Done button.
/// The action is invoked when Done is tapped — typically to clear the
/// owning view's `@FocusState`.
private struct KeyboardDismissToolbarModifier: ViewModifier {

    let action: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: action)
                    .bold()
                    .accessibilityHint("Dismisses the keyboard.")
            }
        }
    }
}

extension View {

    /// Adds a system keyboard toolbar whose trailing Done button runs
    /// `action`. Use this on any screen containing `.decimalPad` or
    /// `.numberPad` fields — HIG: users must always have a visible way
    /// to dismiss the keyboard.
    ///
    /// ```swift
    /// @FocusState private var focusedField: Field?
    ///
    /// Form { ... }
    ///     .keyboardDismissToolbar { focusedField = nil }
    /// ```
    ///
    /// - Parameter action: Runs when Done is tapped. Clear the active
    ///   focus here (for example `{ focusedField = nil }`).
    func keyboardDismissToolbar(
        _ action: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardDismissToolbarModifier(action: action))
    }
}
