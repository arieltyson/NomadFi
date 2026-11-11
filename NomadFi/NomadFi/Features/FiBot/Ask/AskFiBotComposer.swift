// AskFiBotComposer.swift
// NomadFi
//
// The field at the bottom of Ask FiBot.

import SwiftUI

/// A glass field and one button: Ask, or Stop while FiBot is answering.
///
/// The field is multi-line, so the keyboard's return key adds a line and
/// keeps its ordinary look; asking is only ever the Ask button. While the
/// keyboard is up, a Hide Keyboard button sits on the leading side, clear
/// of Ask, and dragging the conversation down dismisses it too.
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
                if isFocused {
                    Button("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") { isFocused = false }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .transition(.scale.combined(with: .opacity))
                }

                TextField("Ask FiBot", text: $text, axis: .vertical)
                    .lineLimit(1...5)
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
        .animation(AnimationTokens.snappy, value: isFocused)
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
