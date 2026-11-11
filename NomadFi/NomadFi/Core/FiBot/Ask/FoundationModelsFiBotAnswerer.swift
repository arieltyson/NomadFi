// FoundationModelsFiBotAnswerer.swift
// NomadFi
//
// Ask FiBot's production answerer: Apple's on-device language model.

import Foundation
import FoundationModels
import OSLog

/// Drafts answers with the on-device system language model.
///
/// Nothing leaves the device: the model runs locally and receives only
/// the fact sheet, never raw records. Facts travel in the prompt rather
/// than the instructions, because they contain text the user's banks
/// and merchants wrote. Each question starts a fresh session so the
/// small context window holds the facts, one previous exchange and the
/// question, rather than a growing transcript.
struct FoundationModelsFiBotAnswerer: FiBotAnswering {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "FiBotAnswerer")

    private static let instructions = """
    You are FiBot, the private finance assistant inside NomadFi. You \
    answer questions about the person's own money using only the \
    numbered facts in the prompt.

    Rules:
    - Use only figures that appear in the facts. You may add or \
    subtract two figures, but do no other arithmetic.
    - Cite the ID of every fact you use, such as F3.
    - Write amounts with their currency code, such as CAD 1,240.50. \
    Never combine amounts in different currencies.
    - Read the question generously: people type quickly, with typos, \
    shorthand and missing words. "hw mch i spnd" means "how much did I \
    spend". Answer what they most likely meant.
    - If the message is a greeting, or you cannot tell what is being \
    asked, reply with one friendly sentence asking what they would like \
    to know about their money, and cite no facts. Never answer an \
    unclear message by reciting a fact.
    - If the facts cannot answer the question, say so briefly and name \
    what NomadFi would need, such as a linked account.
    - Answer in one to three short, plain sentences. No headings, lists \
    or emoji.
    - Describe the person's data; do not give investment, tax or legal \
    advice, and do not tell them what to buy.
    """

    func availability() -> FiBotAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady): .modelNotReady
        case .unavailable: .deviceNotEligible
        }
    }

    func draft(
        question: String,
        sheet: FiBotFactSheet,
        previousExchange: FiBotExchange?,
        correction: String?
    ) async throws -> FiBotAnswerDraft {
        guard availability() == .available else { throw FiBotAskError.unavailable }

        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = Self.prompt(
            question: question,
            sheet: sheet,
            previousExchange: previousExchange,
            correction: correction
        )
        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedAnswer.self,
                options: GenerationOptions(sampling: .greedy)
            )
            return FiBotAnswerDraft(
                text: response.content.answer.trimmingCharacters(in: .whitespacesAndNewlines),
                citedFactIDs: response.content.factIDs
            )
        } catch let error as LanguageModelSession.GenerationError {
            Self.logger.error("Generation failed: \(String(describing: error), privacy: .private)")
            switch error {
            case .exceededContextWindowSize: throw FiBotAskError.tooMuchContext
            case .guardrailViolation, .refusal: throw FiBotAskError.declined
            case .assetsUnavailable: throw FiBotAskError.unavailable
            default: throw FiBotAskError.failed
            }
        } catch {
            Self.logger.error("Generation failed: \(String(describing: error), privacy: .private)")
            throw FiBotAskError.failed
        }
    }

    /// The prompt: facts, the previous exchange, the question and any correction.
    static func prompt(
        question: String,
        sheet: FiBotFactSheet,
        previousExchange: FiBotExchange?,
        correction: String?
    ) -> String {
        var sections = ["Facts:\n\(sheet.promptText)"]
        if let previousExchange {
            sections.append("Previous question: \(previousExchange.question)\nPrevious answer: \(previousExchange.answer)")
        }
        sections.append("Question: \(question)")
        if let correction { sections.append(correction) }
        return sections.joined(separator: "\n\n")
    }
}

/// The structure the model fills in through guided generation.
@Generable
private struct GeneratedAnswer {

    @Guide(description: "The answer in one to three short, plain sentences.")
    var answer: String

    @Guide(description: "The ID of every fact the answer uses, such as F3.")
    var factIDs: [String]
}
