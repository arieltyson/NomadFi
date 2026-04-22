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
//
// Two shapes are exported:
// • `KeyboardDismissToolbarItem` — a `ToolbarContent` value intended
//   to be composed inside an existing `.toolbar { }` block alongside
//   navigation items (Cancel/Save/Close). This is the canonical,
//   most-reliable placement: SwiftUI registers every toolbar item in
//   one pass, avoiding the keyboard-accessory registration race that
//   happens when two separate `.toolbar` modifiers are stacked.
// • `.keyboardDismissToolbar { }` — view modifier for screens whose
//   view hierarchy has no navigation toolbar to merge with. It just
//   wraps `KeyboardDismissToolbarItem` in its own `.toolbar` block so
//   the two call styles stay behaviourally identical.

import SwiftUI

/// A trailing `Done` keyboard-accessory button as composable
/// `ToolbarContent`. Use this inside a single `.toolbar { }` block
/// alongside navigation toolbar items — one `.toolbar` call keeps the
/// keyboard accessory from racing with navigation item registration.
///
/// ```swift
/// @FocusState private var focusedField: Field?
///
/// Form { ... }
///     .toolbar {
///         ToolbarItem(placement: .cancellationAction) { Button("Cancel") { ... } }
///         ToolbarItem(placement: .confirmationAction) { Button("Save") { ... } }
///         KeyboardDismissToolbarItem { focusedField = nil }
///     }
/// ```
struct KeyboardDismissToolbarItem: ToolbarContent {

    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done", action: action)
                .bold()
                .accessibilityHint("Dismisses the keyboard.")
        }
    }
}

/// View-modifier shorthand for screens without any other toolbar
/// content. Prefer embedding ``KeyboardDismissToolbarItem`` inside
/// your existing `.toolbar { }` block when the screen has navigation
/// items — stacking two `.toolbar` modifiers can leave the keyboard
/// group unregistered until the next layout pass.
private struct KeyboardDismissToolbarModifier: ViewModifier {

    let action: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            KeyboardDismissToolbarItem(action: action)
        }
    }
}

extension View {

    /// Adds a system keyboard toolbar whose trailing Done button runs
    /// `action`. Use on screens that have no other `.toolbar { }`
    /// block; otherwise compose ``KeyboardDismissToolbarItem`` inside
    /// your existing toolbar for more reliable registration.
    ///
    /// - Parameter action: Runs when Done is tapped. Clear the active
    ///   focus here (for example `{ focusedField = nil }`).
    func keyboardDismissToolbar(
        _ action: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardDismissToolbarModifier(action: action))
    }
}
