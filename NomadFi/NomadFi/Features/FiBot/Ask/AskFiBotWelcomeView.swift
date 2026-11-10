// AskFiBotWelcomeView.swift
// NomadFi
//
// What Ask FiBot shows before the first question.

import SwiftUI

/// The invitation: the FiBot mark, "Ask FiBot", a promise of privacy
/// and three questions to start with. When Apple Intelligence is not
/// available, the starters give way to one line saying why.
struct AskFiBotWelcomeView: View {

    let availability: FiBotAvailability
    let onAsk: (String) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            VStack(spacing: SpacingTokens.small) {
                FiBotMark()
                Text("Ask FiBot")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityAddTraits(.isHeader)
                Label("Private to this iPhone", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let message = availability.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                FiBotSuggestionList(onAsk: onAsk)
            }
        }
        .padding(SpacingTokens.large)
        .frame(maxWidth: .infinity)
    }
}

/// The sparkles mark, gently breathing unless Reduce Motion is on.
private struct FiBotMark: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "sparkles")
            .font(.largeTitle)
            .imageScale(.large)
            .foregroundStyle(ColorTokens.brandPrimary.gradient)
            .symbolEffect(.breathe, isActive: !reduceMotion)
            .accessibilityHidden(true)
    }
}

/// The starter questions, each one tap from an answer.
private struct FiBotSuggestionList: View {

    let onAsk: (String) -> Void

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: SpacingTokens.small) {
                ForEach(FiBotSuggestion.allCases) { suggestion in
                    Button {
                        onAsk(suggestion.question)
                    } label: {
                        Label(suggestion.question, systemImage: suggestion.systemImage)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: RadiusTokens.card))
                    .controlSize(.large)
                }
            }
        }
    }
}

#Preview {
    AskFiBotWelcomeView(availability: .available) { _ in }
}
