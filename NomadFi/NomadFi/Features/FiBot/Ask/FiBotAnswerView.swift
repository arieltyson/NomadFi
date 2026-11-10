// FiBotAnswerView.swift
// NomadFi
//
// One answer and the proof behind it.

import SwiftUI

/// An answer in plain text, followed by a single line saying whether
/// its figures were checked. That line opens the facts it used.
struct FiBotAnswerView: View {

    let answer: FiBotAnswer

    @State private var isShowingSources = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text(answer.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if answer.verification != .noFigures || !answer.sources.isEmpty {
                Button {
                    isShowingSources = true
                } label: {
                    FiBotVerificationLabel(verification: answer.verification)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the figures this answer used")
            }
        }
        .sheet(isPresented: $isShowingSources) {
            FiBotSourcesSheet(answer: answer)
                .presentationDetents([.medium, .large])
        }
    }
}

/// "Checked against your data", or a caution when a figure was not.
struct FiBotVerificationLabel: View {

    let verification: FiBotAnswerVerification

    var body: some View {
        Group {
            switch verification {
            case .verified:
                Label("Checked against your data", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(ColorTokens.positive)
            case .noFigures:
                Label("Sources", systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(.secondary)
            case .unverified:
                Label("Some figures couldn't be checked", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.warning)
            }
        }
        .font(.footnote)
    }
}

#Preview {
    FiBotAnswerView(answer: FiBotAnswer(
        text: "You've spent CAD 820.40 so far this month, mostly on Food and Dining.",
        sources: [FiBotFact(id: "F5", topic: "Spending this month in CAD", statement: "CAD 820.40 across 23 transactions")],
        verification: .verified
    ))
    .padding()
}
