import Testing
@testable import NomadFi

struct FiBotAskLoopTests {

    private let sheet = FiBotFactSheet(
        facts: [FiBotFact(id: "F1", topic: "Spending this month in CAD", statement: "CAD 820.40 across 23 transactions")],
        hasFinancialData: true
    )

    @Test func aVerifiedFirstDraftIsReturnedWithoutRetrying() async throws {
        let answerer = ScriptedFiBotAnswerer(drafts: [
            FiBotAnswerDraft(text: "You've spent CAD 820.40.", citedFactIDs: ["F1"]),
        ])
        let answer = try await FiBotAskLoop(answerer: answerer).answer("How much?", from: sheet)
        #expect(answer.verification == .verified)
        #expect(await answerer.corrections.isEmpty)
    }

    @Test func aFailedCheckIsSentBackAndTheCorrectedDraftWins() async throws {
        let answerer = ScriptedFiBotAnswerer(drafts: [
            FiBotAnswerDraft(text: "You've spent CAD 900.00.", citedFactIDs: ["F1"]),
            FiBotAnswerDraft(text: "You've spent CAD 820.40.", citedFactIDs: ["F1"]),
        ])
        let answer = try await FiBotAskLoop(answerer: answerer).answer("How much?", from: sheet)
        #expect(answer.text == "You've spent CAD 820.40.")
        #expect(answer.verification == .verified)
        let corrections = await answerer.corrections
        #expect(corrections.count == 1)
        #expect(corrections.first?.contains("900.00") == true)
    }

    @Test func aDraftThatNeverVerifiesIsReturnedWithItsCaution() async throws {
        let answerer = ScriptedFiBotAnswerer(drafts: [
            FiBotAnswerDraft(text: "You've spent CAD 900.00.", citedFactIDs: ["F1"]),
        ])
        let answer = try await FiBotAskLoop(answerer: answerer).answer("How much?", from: sheet)
        #expect(answer.verification == .unverified(figures: ["900.00"]))
        #expect(await answerer.corrections.count == FiBotAskLoop.maximumAttempts - 1)
    }
}
