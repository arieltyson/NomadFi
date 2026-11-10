// AskFiBotComposer.swift
// NomadFi
//
// The field at the bottom of Ask FiBot.

import SwiftUI

/// A glass field and one button: Ask, or Stop while FiBot is answering.
struct AskFiBotComposer: View {

    @Binding var text: String
    let isEnabled: Bool
    let isAnswering: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        GlassEffectContainer(spacing: SpacingTokens.small) {
            HStack(alignment: .bottom, spacing: SpacingTokens.small) {
                TextField("Ask FiBot", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.vertical, SpacingTokens.small)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: RadiusTokens.card))

                if isAnswering {
                    Button("Stop", systemImage: "stop.fill", action: onStop)
                        .composerButton()
                } else {
                    Button("Ask", systemImage: "arrow.up", action: send)
                        .composerButton()
                        .disabled(!canSend)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.bottom, SpacingTokens.xSmall)
    }

    private func send() {
        guard canSend else { return }
        onSend()
        isFocused = false
    }
}

private extension View {
    /// The round, prominent glass button beside the field.
    func composerButton() -> some View {
        labelStyle(.iconOnly)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
    }
}
