import Foundation
import Testing
@testable import FiBotEngine

struct FiBotContextTests {
    @Test func localDaysPreserveCalendarDatesAcrossDaylightSaving() throws {
        let zone = try #require(TimeZone(identifier: "America/Vancouver"))
        let midnightUTC = try #require(FiBotCalendar.date("2026-10-06"))
        #expect(FiBotCalendar.localDay(midnightUTC, in: zone) == "2026-10-05")
        for day in ["2025-03-09", "2025-11-02"] {
            let local = try #require(FiBotCalendar.localDate(day, in: zone))
            #expect(FiBotCalendar.localDay(local, in: zone) == day)
        }
        let first = try #require(FiBotCalendar.localDate("2025-11-02", in: zone))
        let next = try #require(FiBotCalendar.localDate("2025-11-03", in: zone))
        #expect(next.timeIntervalSince(first) == 25 * 3600)
        #expect(FiBotCalendar.adding(7, to: "2026-10-28") == "2026-11-04")
        #expect(FiBotCalendar.localDate("2026-02-30", in: zone) == nil)
    }

    @Test func savedPlanKeepsItsTimeZoneAndLegacyPlansRetainUTC() throws {
        var plan = FiBotPlan()
        plan.timeZoneIdentifier = "America/Vancouver"
        let saved = try JSONEncoder().encode(plan)
        let restored = try JSONDecoder().decode(FiBotPlan.self, from: saved)
        #expect(restored.timeZone.identifier == "America/Vancouver")
        var legacy = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        legacy.removeValue(forKey: "timeZoneIdentifier")
        let migrated = try JSONDecoder().decode(FiBotPlan.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(migrated.timeZone.secondsFromGMT() == 0)
    }

    @Test func invalidTimeZonePreventsConfirmedCoverage() {
        var plan = FiBotPlan()
        plan.timeZoneIdentifier = "invalid-zone"
        plan.confirmedOn = "2026-10-06"
        plan.coverage.accountsComplete = true
        #expect(!FiBotContextBuilder.build(plan: plan, on: "2026-10-06").coverage.accountsComplete)
    }

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
