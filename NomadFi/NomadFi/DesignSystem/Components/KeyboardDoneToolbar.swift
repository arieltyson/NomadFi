// KeyboardDoneToolbar.swift
// NomadFi
//
// A Done button above the keyboard, for every keyboard in the app.

import SwiftUI

/// Adds the system keyboard toolbar's Done button and drag-to-dismiss.
///
/// The return key is not a dismissal. A `.decimalPad` has no return
/// key at all, and on a multi-line field return inserts a newline —
/// so a screen that relies on it leaves people with no way out.
///
/// The modifier owns the dismissal rather than taking a closure for
/// it: a caller that has to supply `{ focusedField = nil }` is a
/// caller that can forget to. Dragging the keyboard away is wired up
/// here too, so the gesture and the button always arrive together.
///
/// Attach it *inside* the screen's `NavigationStack`. SwiftUI drops
/// keyboard toolbar items attached outside the stack — which is what
/// made the button vanish after the first focus in an earlier build.
///
/// ```swift
/// @FocusState private var focusedField: Field?
///
/// NavigationStack {
///     Form { … }
///         .keyboardDone($focusedField)
/// }
/// ```
private struct KeyboardDoneToolbar<Value: Hashable>: ViewModifier {

    let focus: FocusState<Value?>.Binding

    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    KeyboardDoneButton { focus.wrappedValue = nil }
                }
            }
    }
}

/// The single-field variant, for a `@FocusState<Bool>`.
private struct SingleFieldKeyboardDoneToolbar: ViewModifier {

    let focus: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    KeyboardDoneButton { focus.wrappedValue = false }
                }
            }
    }
}

/// The button itself, so its wording and identifier are decided once.
///
/// Deliberately the system's own button rather than a filled
/// ``NomadFiActionButton``: a keyboard accessory is chrome, and
/// dressing it in the app's filled treatment would make dismissing
/// the keyboard look like the most important action on screen.
private struct KeyboardDoneButton: View {

    let dismiss: () -> Void

    var body: some View {
        Button("Done", action: dismiss)
            .accessibilityIdentifier("keyboard.done")
            .accessibilityLabel("Done editing")
    }
}

extension View {

    /// Adds the standard Done button and drag-to-dismiss to a screen
    /// that raises a keyboard, clearing `focus` when either is used.
    func keyboardDone<Value: Hashable>(_ focus: FocusState<Value?>.Binding) -> some View {
        modifier(KeyboardDoneToolbar(focus: focus))
    }

    /// The single-field variant.
    func keyboardDone(_ focus: FocusState<Bool>.Binding) -> some View {
        modifier(SingleFieldKeyboardDoneToolbar(focus: focus))
    }
}
