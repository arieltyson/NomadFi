import Foundation
import Testing
@testable import FiBotEngine

struct FiBotContextTests {
    @Test func monthlyDatesDoNotDriftAfterFebruaryAndIncomeStopsAtEmploymentEnd() {
        var plan = FiBotPlan()
        plan.confirmedOn = "2027-01-01"
        plan.schedules = [.init(label: "Net pay", accountID: "cash", money: .init(1000, currency: "CAD"), kind: .netIncome,
                                firstDate: "2027-01-31", lastDate: "2027-03-31", cadence: .monthly, confirmedOn: "2027-01-01")]
        let result = FiBotContextBuilder.build(plan: plan, on: "2027-01-01")
        #expect(result.flows.map(\.date) == ["2027-01-31", "2027-02-28", "2027-03-31"])
    }
    @Test func expiredConfirmationAndInvalidScheduleInvalidateCoverage() {
        var plan = FiBotPlan()
        plan.coverage = .init(incomeConfirmed: true, obligationsConfirmed: true, accountsComplete: true, spendingIncluded: true, debtPaymentsIncluded: true)
        plan.confirmedOn = "2026-08-01"
        #expect(!FiBotContextBuilder.build(plan: plan, on: "2026-10-06").coverage.incomeConfirmed)
        plan.confirmedOn = "2026-10-06"
        plan.schedules = [.init(label: "Bill", accountID: "cash", money: .init(10, currency: "CAD"), kind: .essential,
                                firstDate: "2026-02-30", lastDate: "2027-01-01", cadence: .once, confirmedOn: "2026-10-06")]
        #expect(!FiBotContextBuilder.build(plan: plan, on: "2026-10-06").coverage.obligationsConfirmed)
    }
    @Test func evidenceIDsAreUniqueAndEveryRuleCitationResolves() {
        #expect(Set(FiBotEvidenceRegistry.entries.map(\.id)).count == 6)
        for id in ["R3", "R4", "R5"] { #expect(FiBotEvidenceRegistry.evidence(for: id)?.url.scheme == "https") }
    }
}
