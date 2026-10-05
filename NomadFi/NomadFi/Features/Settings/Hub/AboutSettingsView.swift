// AboutSettingsView.swift
// NomadFi
//
// About page pulled out of the Settings root so the hub stays short.
// Version, product-mission tag, and a short statement of who the app
// is built for — no legal copy here (the Privacy Policy lives under
// Privacy & Security).

import SwiftUI

struct AboutSettingsView: View {

    var body: some View {
        List {
            Section {
                LabeledContent("Version") {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("App version \(appVersion)")

                Label {
                    Text("Built for International Students")
                        .font(TypographyTokens.body)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundStyle(ColorTokens.brandPrimary)
                }
                .accessibilityLabel("NomadFi is built specifically for international students managing money across borders")

                Label {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text("Decision Assistant, Not a Ledger")
                            .font(TypographyTokens.body)
                        Text("NomadFi helps you pick the right card, protect credit, reduce FX waste, and learn jurisdiction-aware tax concepts — without manual bookkeeping.")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(ColorTokens.brandPrimary)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("About NomadFi")
            }
        }
        .navigationTitle("About NomadFi")
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
