// HostedPilotAccessSection.swift
// NomadFi
//
// Debug builds only: the Apple ID the server refused, to allow it.

#if DEBUG
import SwiftUI

/// Shows this device's own Apple user identifier after the server
/// refused it, so the owner can add it to `APPLE_ALLOWED_SUBJECTS`.
struct HostedPilotAccessSection: View {

    let subject: String

    var body: some View {
        Section {
            Text(subject)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
            ShareLink("Share Apple ID", item: subject)
        } header: {
            Text("Pilot access (Debug)")
        } footer: {
            Text("Add this identifier to the server's APPLE_ALLOWED_SUBJECTS, then sign in again.")
        }
    }
}
#endif
