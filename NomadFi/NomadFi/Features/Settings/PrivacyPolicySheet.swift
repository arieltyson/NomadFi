// PrivacyPolicySheet.swift
// NomadFi
//
// Displays the in-app privacy policy in a scrollable sheet,
// accessible from Settings for transparency and compliance.

import SwiftUI

/// A sheet presenting NomadFi's privacy policy in plain language.
///
/// Written for international students who may not be native English
/// speakers. Avoids legal jargon and clearly explains what data
/// NomadFi does (and does not) collect.
struct PrivacyPolicySheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(DataGovernancePolicy.privacyPolicyText)
                    .font(TypographyTokens.body)
                    .padding(SpacingTokens.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .glassToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    PrivacyPolicySheet()
}
