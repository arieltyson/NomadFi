// FiBotSourcesSheet.swift
// NomadFi
//
// The facts behind one answer, and how they were checked.

import SwiftUI

/// Lists the facts an answer cited and, when a figure failed its
/// check, which ones. Ends with how FiBot keeps the question private.
struct FiBotSourcesSheet: View {

    let answer: FiBotAnswer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FiBotVerificationLabel(verification: answer.verification)
                } footer: {
                    Text(explanation)
                }

                if !answer.sources.isEmpty {
                    Section("Figures used") {
                        ForEach(answer.sources) { fact in
                            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                                Text(fact.topic)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(fact.statement)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section {
                    Label("Answered on this iPhone by Apple Intelligence. Your data and questions never leave it, and conversations aren't saved.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    private var explanation: String {
        switch answer.verification {
        case .verified:
            String(localized: "Every figure in this answer matches NomadFi's own records below.")
        case .noFigures:
            String(localized: "This answer states no figures to check.")
        case .unverified(let figures):
            String(localized: "FiBot could not match \(figures.formatted(.list(type: .and))) to your records, even after checking again. Treat those figures with care.")
        }
    }
}
