// KeyboardDoneToolbar.swift
// NomadFi
//
// A Done button above the keyboard, for every keyboard in the app.

import SwiftUI

/// Adds a Done button above the keyboard and drag-to-dismiss.
///
/// The return key is not a dismissal. A `.decimalPad` has no return
/// key at all, and on a multi-line field return inserts a newline,
/// so a screen that relies on it leaves people with no way out.
///
/// The modifier owns the dismissal rather than taking a closure for
/// it: a caller that has to supply `{ focusedField = nil }` is a
/// caller that can forget to. Dragging the keyboard away is wired up
/// here too, so the gesture and the button always arrive together.
///
/// The button appears whenever `focus` holds a field, so it is there
/// from the first focus, including focus set as a sheet opens.
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
            .safeAreaInset(edge: .bottom) {
                if focus.wrappedValue != nil {
                    KeyboardDoneBar { focus.wrappedValue = nil }
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
            .safeAreaInset(edge: .bottom) {
                if focus.wrappedValue {
                    KeyboardDoneBar { focus.wrappedValue = false }
                }
            }
    }
}

/// Done, trailing, in a slim bar that rides on top of the keyboard.
///
/// Drawn by the app rather than placed in the system keyboard toolbar:
/// on iOS 26 a `.keyboard` toolbar item often fails to appear when focus
/// is set as a screen or sheet opens, and shows only after focus moves,
/// which left people without a visible way to dismiss the keyboard.
private struct KeyboardDoneBar: View {

    let dismiss: () -> Void

    var body: some View {
        HStack {
            Spacer()
            KeyboardDoneButton(dismiss: dismiss)
                .buttonStyle(.glass)
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.xSmall)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
