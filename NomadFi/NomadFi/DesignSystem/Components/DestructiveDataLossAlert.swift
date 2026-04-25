// DestructiveDataLossAlert.swift
// NomadFi
//
// Single, opinionated chokepoint for "destructive operations that
// risk irretrievable data loss". Wraps SwiftUI's `.alert(...)`
// modifier with a fixed shape:
//
//   • Centered modal presentation on every size class — never
//     anchored as a popover (that's `.confirmationDialog`'s job).
//   • The destructive action carries `Button(role: .destructive)`
//     so the system renders it in the platform's destructive
//     accent and announces "Destructive" to VoiceOver.
//   • A "Cancel" button with `role: .cancel` is *always* present,
//     so the Escape key on hardware keyboards and the
//     swipe-down-to-dismiss gesture both resolve the alert
//     without a destructive side effect.
//
// When to use this vs `.confirmationDialog` (Apple HIG):
//
//   • Use this primitive when the action **cannot be undone** and
//     would result in irretrievable data loss (deleting a saved
//     draft, wiping every record on the device).
//   • Use plain `.confirmationDialog` (action sheet on iPhone,
//     popover on iPad) for **reversible** destructive actions —
//     e.g. "Clear these dates? You can re-enter them at any time."
//     The lighter sheet is correct for the lighter consequence.
//
// The naming is deliberately explicit (`DataLoss`) so a future
// contributor who can't honestly call something "irretrievable
// data loss" reaches for `.confirmationDialog` instead. That
// self-documenting boundary is the point of the primitive — it
// makes the design-system rule a one-line, greppable contract.
//
// HIG references:
//   • Alerts — "Display alerts only for critical information,
//     such as errors and important confirmations."
//   • Confirmation dialogs — "When you display a destructive
//     option, attach the button to a confirmation dialog so
//     people can confirm it."

import SwiftUI

extension View {

    /// Presents a centered, modal `.alert` for an irreversible
    /// destructive action. The destructive button always carries
    /// `role: .destructive`, and a `Cancel` button with
    /// `role: .cancel` is always provided so keyboard and gesture
    /// dismissal can never trigger the destructive path.
    ///
    /// Use this only when the action would cause irretrievable
    /// data loss. For reversible destructive actions (e.g. "Clear
    /// these dates?") prefer the lighter `.confirmationDialog`
    /// affordance.
    ///
    /// - Parameters:
    ///   - title: Localised question presented as the alert
    ///     headline (e.g. "Delete this draft from this device?").
    ///   - isPresented: Standard SwiftUI alert presentation
    ///     binding.
    ///   - confirmationLabel: Localised label for the destructive
    ///     button (e.g. "Delete draft", "Delete Everything").
    ///   - message: Localised explanation of what the user is
    ///     about to lose. Per HIG, this is what tells the user
    ///     the action is permanent.
    ///   - onConfirm: Closure invoked when the user taps the
    ///     destructive button.
    func destructiveDataLossAlert(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        confirmationLabel: LocalizedStringKey,
        message: LocalizedStringKey,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button(confirmationLabel, role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
