// FiBotConversationView.swift
// NomadFi
//
// The questions and answers of one Ask FiBot conversation.

import SwiftUI

/// The conversation, oldest first, with a quiet progress line while
/// FiBot reads and checks.
struct FiBotConversationView: View {

    let messages: [FiBotMessage]
    let isAnswering: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: SpacingTokens.large) {
            ForEach(messages) { message in
                switch message.content {
                case .question(let question):
                    FiBotQuestionBubble(text: question)
                case .answer(let answer):
                    FiBotAnswerView(answer: answer)
                case .failure(let error):
                    Label(error.message, systemImage: "exclamationmark.bubble")
                        .foregroundStyle(.secondary)
                }
            }
            if isAnswering {
                FiBotThinkingView()
            }
        }
        .padding(SpacingTokens.medium)
    }
}

/// A question, set to the trailing side in the action tint.
private struct FiBotQuestionBubble: View {

    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(ColorTokens.onActionTint)
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
            .background(ColorTokens.actionTint, in: .rect(cornerRadius: RadiusTokens.card))
            .padding(.leading, SpacingTokens.xxLarge)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("You asked: \(text)")
    }
}

/// Shown while an answer is being drafted and checked.
private struct FiBotThinkingView: View {

    var body: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            ProgressView()
            Text("Reading and checking your finances…")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }
}
