// PortfolioLabTokenView.swift
// NomadFi
//
// Adds or removes the person's own Tiingo token for real prices.

import SwiftUI

/// Tiingo lets apps fetch prices only with each person's own token, so
/// NomadFi asks for one instead of serving prices itself.
struct PortfolioLabTokenView: View {

    let viewModel: PortfolioLabViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var rejected = false

    var body: some View {
        Form {
            Section {
                SecureField("API token", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: token) { rejected = false }
                if rejected {
                    Label("That doesn't look like a Tiingo token.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ColorTokens.negative)
                }
            } header: {
                Text("Tiingo Token")
            } footer: {
                Text("Create a free Tiingo account, then copy the token from its API page. It's stored in this iPhone's Keychain and sent only to Tiingo.")
            }

            Section {
                Link("Get a Free Token", destination: TiingoPriceService.signUpURL)
                if viewModel.hasToken {
                    Button("Remove Token", role: .destructive) {
                        viewModel.removeToken()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Real Prices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.saveToken(token) {
                        viewModel.source = .live
                        dismiss()
                    } else {
                        rejected = true
                    }
                }
                .disabled(token.isEmpty)
            }
        }
    }
}
