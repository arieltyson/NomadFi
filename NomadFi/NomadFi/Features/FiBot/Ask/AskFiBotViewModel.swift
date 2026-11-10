// AskFiBotViewModel.swift
// NomadFi
//
// State and actions for the Ask FiBot conversation.

import Foundation
import Observation

/// Drives Ask FiBot: the conversation, the composer and the loop.
///
/// Conversations live only in memory. Nothing is saved, so closing the
/// app or starting over leaves no trace of what was asked.
@MainActor
@Observable
final class AskFiBotViewModel {

    /// The longest question accepted.
    static let questionLimit = 500

    private(set) var messages: [FiBotMessage] = []
    private(set) var isAnswering = false
    private(set) var availability: FiBotAvailability

    /// The composer's text.
    var draft = ""

    private let loop: FiBotAskLoop
    private let answerer: any FiBotAnswering
    private var answerTask: Task<Void, Never>?

    init(answerer: any FiBotAnswering = FoundationModelsFiBotAnswerer()) {
        self.answerer = answerer
        self.loop = FiBotAskLoop(answerer: answerer)
        self.availability = answerer.availability()
    }

    /// Whether the composer's text can be sent.
    var canSend: Bool {
        availability == .available && !isAnswering && !trimmedDraft.isEmpty
    }

    /// Whether the conversation has started.
    var hasConversation: Bool { !messages.isEmpty }

    /// Re-reads availability, e.g. after returning from Settings.
    func refreshAvailability() {
        availability = answerer.availability()
    }

    /// Sends the composer's text.
    func send(using source: some FiBotFactSource) {
        guard canSend else { return }
        ask(trimmedDraft, using: source)
        draft = ""
    }

    /// Asks `question` from a fresh fact sheet.
    func ask(_ question: String, using source: some FiBotFactSource) {
        let question = String(question.prefix(Self.questionLimit))
        guard availability == .available, !isAnswering, !question.isEmpty else { return }

        let previous = lastExchange
        messages.append(FiBotMessage(.question(question)))
        isAnswering = true

        let sheet: FiBotFactSheet
        do {
            sheet = try source.currentSheet()
        } catch {
            finish(with: .failure(.failed))
            return
        }

        answerTask = Task { [loop] in
            let content: FiBotMessage.Content
            do {
                content = .answer(try await loop.answer(question, from: sheet, after: previous))
            } catch is CancellationError {
                return
            } catch let error as FiBotAskError {
                content = .failure(error)
            } catch {
                content = .failure(.failed)
            }
            // A stopped answer may still return; it must not land in
            // a conversation that has moved on.
            guard !Task.isCancelled else { return }
            finish(with: content)
        }
    }

    /// Stops the answer in progress.
    func stop() {
        answerTask?.cancel()
        answerTask = nil
        isAnswering = false
    }

    /// Clears the conversation.
    func startOver() {
        stop()
        messages.removeAll()
        draft = ""
    }

    // MARK: - Private

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func finish(with content: FiBotMessage.Content) {
        guard isAnswering else { return }
        messages.append(FiBotMessage(content))
        isAnswering = false
        answerTask = nil
    }

    /// The most recent answered question, for follow-ups.
    private var lastExchange: FiBotExchange? {
        guard let answerIndex = messages.lastIndex(where: {
            if case .answer = $0.content { true } else { false }
        }), answerIndex > 0,
              case .question(let question) = messages[answerIndex - 1].content,
              case .answer(let answer) = messages[answerIndex].content
        else { return nil }
        return FiBotExchange(question: question, answer: answer.text)
    }
}
