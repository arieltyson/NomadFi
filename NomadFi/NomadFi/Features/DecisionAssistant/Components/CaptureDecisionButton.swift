// CaptureDecisionButton.swift
// NomadFi
//
// The Decisions tab's add button.

import SwiftUI

/// The trailing **+** that captures a decision.
///
/// A tap opens the typed form; a long press offers the alternative,
/// describing the decision to on-device Apple Intelligence — the same
/// pattern as Mail's compose button. One control in the toolbar, where
/// people already look to add something, instead of a hero card
/// competing with the decisions themselves.
struct CaptureDecisionButton: View {

    /// Opens the typed capture form.
    let onCapture: () -> Void

    /// Opens the Apple Intelligence intake.
    let onDescribe: () -> Void

    var body: some View {
        Menu {
            Button("Describe with Apple Intelligence", systemImage: "apple.intelligence", action: onDescribe)
        } label: {
            Label("Capture Decision", systemImage: "plus")
        } primaryAction: {
            onCapture()
        }
        .accessibilityHint("Touch and hold to describe it with Apple Intelligence.")
        .accessibilityIdentifier("decisions.capture")
    }
}

#Preview {
    NavigationStack {
        Text("Decisions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    CaptureDecisionButton(onCapture: {}, onDescribe: {})
                }
            }
    }
}
