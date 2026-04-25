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
// Single-shape contract (incident learning):
//   The previous version of this file also exported a
//   `.keyboardDismissToolbar { }` view modifier that internally
//   wrapped the toolbar item in its own `.toolbar { }` block. When a
//   screen called `.toolbar { ... }` for navigation items AND
//   `.keyboardDismissToolbar { }` afterwards, the two `.toolbar`
//   modifiers raced at registration time and the keyboard
//   `ToolbarItemGroup` would silently fail to attach to the
//   keyboard accessory — leaving the user stuck on a `.decimalPad`
//   keyboard with no Done button. The modifier has been retired so
//   only the `ToolbarContent` shape remains; every call site
//   composes it inside its single `.toolbar { }` block alongside
//   any navigation items, which is the placement Apple's keyboard
//   `ToolbarItemPlacement` documentation explicitly recommends.

import SwiftUI

/// A trailing `Done` keyboard-accessory button as composable
/// `ToolbarContent`. Compose this inside the screen's single
/// `.toolbar { }` block alongside navigation toolbar items — one
/// `.toolbar` call keeps the keyboard accessory from racing with
/// navigation item registration.
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
