import Testing
@testable import NomadFi

struct FiBotFigureVerifierTests {

    private let sheet = FiBotFactSheet(
        facts: [
            FiBotFact(id: "F1", topic: "Spending this month in CAD", statement: "CAD 820.40 across 23 transactions"),
            FiBotFact(id: "F2", topic: "Spending last month in CAD", statement: "CAD 1240.50 across 31 transactions"),
            FiBotFact(id: "F3", topic: "Subscription Netflix", statement: "CAD 16.99 monthly, renews 2026-11-15"),
        ],
        hasFinancialData: true
    )

    private func verify(_ text: String, cites ids: [String], question: String = "") -> FiBotAnswerVerification {
        FiBotFigureVerifier.verify(
            FiBotAnswerDraft(text: text, citedFactIDs: ids),
            against: sheet,
            question: question
        ).verification
    }

    @Test func figuresCopiedFromCitedFactsVerify() {
        #expect(verify("You've spent CAD 820.40 across 23 transactions this month.", cites: ["F1"]) == .verified)
    }

    @Test func groupingSeparatorsAndRoundingStillVerify() {
        #expect(verify("Last month came to CAD 1,240.50, about 1,241 rounded.", cites: ["F2"]) == .verified)
        #expect(verify("Roughly CAD 1,240 last month.", cites: ["F2"]) == .verified)
    }

    @Test func sumsAndDifferencesOfCitedFiguresVerify() {
        #expect(verify("That's CAD 420.10 less than last month.", cites: ["F1", "F2"]) == .verified)
    }

    @Test func percentagesMustBeARatioOfCitedFigures() {
        #expect(verify("This month is 66% of last month.", cites: ["F1", "F2"]) == .verified)
        #expect(verify("This month is 12% of last month.", cites: ["F1", "F2"]) == .unverified(figures: ["12"]))
    }

    @Test func aFigureFromAnUncitedFactDoesNotVerify() {
        #expect(verify("Netflix costs CAD 16.99.", cites: ["F1"]) == .unverified(figures: ["16.99"]))
    }

    @Test func anInventedFigureIsReported() {
        #expect(verify("You spent CAD 900.00 this month.", cites: ["F1"]) == .unverified(figures: ["900.00"]))
    }

    @Test func figuresFromTheQuestionCountAsKnown() {
        #expect(verify("A CAD 500 purchase is less than your CAD 820.40 spend.", cites: ["F1"], question: "Can I spend 500?") == .verified)
    }

    @Test func datesInCitedFactsVerify() {
        #expect(verify("Netflix renews on November 15.", cites: ["F3"]) == .verified)
    }

    @Test func answersWithoutFiguresNeedNoCheck() {
        #expect(verify("NomadFi has no investment accounts yet.", cites: []) == .noFigures)
    }

    @Test func unknownCitationsAreDroppedFromSources() {
        let result = FiBotFigureVerifier.verify(
            FiBotAnswerDraft(text: "CAD 820.40", citedFactIDs: ["F1", "F99"]),
            against: sheet,
            question: ""
        )
        #expect(result.sources.map(\.id) == ["F1"])
    }
}
