import Testing
@testable import NomadFi

@MainActor
struct AskFiBotViewModelTests {

    private let source = StaticFiBotFactSource(sheet: FiBotFactSheet(
        facts: [FiBotFact(id: "F1", topic: "Spending this month in CAD", statement: "CAD 820.40 across 23 transactions")],
        hasFinancialData: true
    ))

    private func answered(_ viewModel: AskFiBotViewModel) async {
        while viewModel.isAnswering { await Task.yield() }
    }

    @Test func askingAppendsTheQuestionThenAVerifiedAnswer() async {
        let viewModel = AskFiBotViewModel(answerer: ScriptedFiBotAnswerer(drafts: [
            FiBotAnswerDraft(text: "You've spent CAD 820.40.", citedFactIDs: ["F1"]),
        ]))
        viewModel.draft = "  How much have I spent?  "
        viewModel.send(using: source)
        #expect(viewModel.draft.isEmpty)
        await answered(viewModel)

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages.first?.content == .question("How much have I spent?"))
        guard case .answer(let answer) = viewModel.messages.last?.content else {
            Issue.record("Expected an answer")
            return
        }
        #expect(answer.verification == .verified)
    }

    @Test func nothingCanBeSentWhileAppleIntelligenceIsUnavailable() {
        let viewModel = AskFiBotViewModel(answerer: ScriptedFiBotAnswerer(drafts: [], availability: .appleIntelligenceNotEnabled))
        viewModel.draft = "How much cash do I have?"
        #expect(!viewModel.canSend)
        viewModel.send(using: source)
        #expect(viewModel.messages.isEmpty)
    }

    @Test func aFailureBecomesAMessageRatherThanAnError() async {
        let viewModel = AskFiBotViewModel(answerer: ScriptedFiBotAnswerer(drafts: []))
        viewModel.ask("Anything", using: source)
        await answered(viewModel)
        #expect(viewModel.messages.last?.content == .failure(.failed))
    }

    @Test func startingOverClearsTheConversation() async {
        let viewModel = AskFiBotViewModel(answerer: ScriptedFiBotAnswerer(drafts: [
            FiBotAnswerDraft(text: "No figures here.", citedFactIDs: []),
        ]))
        viewModel.ask("Hello", using: source)
        await answered(viewModel)
        viewModel.startOver()
        #expect(!viewModel.hasConversation)
        #expect(!viewModel.isAnswering)
    }
}
