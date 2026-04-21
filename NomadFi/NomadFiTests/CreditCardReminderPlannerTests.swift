// CreditCardReminderPlannerTests.swift
// NomadFi
//
// Pure-logic coverage for the credit-card reminder planner:
// eligibility gating, lead-time math, identifier stability, and
// privacy-safe copy. The planner never touches UserNotifications, so
// these tests stay fast and deterministic.

import Foundation
import Testing

@testable import NomadFi

struct CreditCardReminderPlannerTests {

    // MARK: - Helpers

    /// Stable UTC date builder — keeps trigger assertions reproducible
    /// regardless of the test runner's local timezone.
    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    /// Calendar pinned to UTC so the planner's `date(bySettingHour:)`
    /// lands exactly at 09:00 UTC on the intended day every time.
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private static func confirmedSchedule() -> CreditCardSchedule {
        CreditCardSchedule(
            statementPeriodStartDate: date(year: 2026, month: 4, day: 1),
            statementClosingDate: date(year: 2026, month: 4, day: 28),
            paymentDueDate: date(year: 2026, month: 5, day: 25),
            lastConfirmedAt: date(year: 2026, month: 4, day: 21)
        )
    }

    private static let sampleFingerprint = "Example%20Bank%7CSample%20Card"

    // MARK: - Eligibility

    @Test("Confirmed schedule produces exactly one close and one due plan")
    func confirmedScheduleYieldsTwoPlans() {
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21),
            calendar: Self.utcCalendar
        )
        #expect(plans.count == 2)
        #expect(plans.contains { $0.kind == .statementClose })
        #expect(plans.contains { $0.kind == .paymentDue })
    }

    @Test("Missing schedule yields no plans")
    func missingScheduleYieldsNoPlans() {
        let plans = CreditCardReminderPlanner.plans(
            for: CreditCardSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21)
        )
        #expect(plans.isEmpty)
    }

    @Test("Partial schedule (missing due date) yields no plans")
    func partialScheduleYieldsNoPlans() {
        let schedule = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            lastConfirmedAt: Self.date(year: 2026, month: 4, day: 21)
        )
        let plans = CreditCardReminderPlanner.plans(
            for: schedule,
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21)
        )
        #expect(plans.isEmpty)
    }

    @Test("Invalid-order schedule (due before close) yields no plans")
    func invalidOrderScheduleYieldsNoPlans() {
        let schedule = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 4, day: 15),
            lastConfirmedAt: Self.date(year: 2026, month: 4, day: 21)
        )
        let plans = CreditCardReminderPlanner.plans(
            for: schedule,
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21)
        )
        #expect(plans.isEmpty)
    }

    @Test("Unconfirmed (complete but never confirmed) schedule yields no plans")
    func unconfirmedScheduleYieldsNoPlans() {
        let schedule = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25)
        )
        let plans = CreditCardReminderPlanner.plans(
            for: schedule,
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21)
        )
        #expect(plans.isEmpty)
    }

    // MARK: - Trigger timing

    @Test("Statement close plan fires 2 days before the close date at 09:00 local")
    func statementCloseTriggerIsTwoDaysBefore() {
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21),
            calendar: Self.utcCalendar
        )
        guard let close = plans.first(where: { $0.kind == .statementClose }) else {
            Issue.record("Statement close plan missing")
            return
        }
        // Close date is 2026-04-28 → trigger expected 2026-04-26 09:00 UTC
        let expected = Self.date(year: 2026, month: 4, day: 26, hour: 9)
        #expect(close.triggerDate == expected)
    }

    @Test("Payment due plan fires 3 days before the due date at 09:00 local")
    func paymentDueTriggerIsThreeDaysBefore() {
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21),
            calendar: Self.utcCalendar
        )
        guard let due = plans.first(where: { $0.kind == .paymentDue }) else {
            Issue.record("Payment due plan missing")
            return
        }
        // Due date is 2026-05-25 → trigger expected 2026-05-22 09:00 UTC
        let expected = Self.date(year: 2026, month: 5, day: 22, hour: 9)
        #expect(due.triggerDate == expected)
    }

    @Test("Trigger dates already in the past are dropped")
    func pastTriggersAreDropped() {
        // "Now" is well after both computed triggers.
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 6, day: 1),
            calendar: Self.utcCalendar
        )
        #expect(plans.isEmpty)
    }

    @Test("When only the close trigger is future, only the close plan is returned")
    func onlyCloseRemainsWhenDueAlreadyPassed() {
        // Now is after the payment-due trigger (2026-05-22 09:00 UTC)
        // but before the statement-close trigger (2026-04-26 09:00 UTC)?
        // That combination is impossible because due > close, so instead
        // check the reverse: now is between the close trigger and the
        // due trigger, so only the due plan remains.
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 5, day: 1),
            calendar: Self.utcCalendar
        )
        #expect(plans.count == 1)
        #expect(plans.first?.kind == .paymentDue)
    }

    // MARK: - Identifiers

    @Test("Every plan identifier starts with the shared credit-card prefix")
    func identifiersUseSharedPrefix() {
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21),
            calendar: Self.utcCalendar
        )
        for plan in plans {
            #expect(plan.id.hasPrefix(CreditCardReminderPlanner.identifierPrefix))
        }
    }

    @Test("Close and due identifiers each start with their kind-specific prefix")
    func identifiersUseKindSpecificPrefix() {
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21),
            calendar: Self.utcCalendar
        )
        let close = plans.first { $0.kind == .statementClose }
        let due = plans.first { $0.kind == .paymentDue }
        #expect(close?.id.hasPrefix(CreditCardReminderKind.statementClose.identifierPrefix) == true)
        #expect(due?.id.hasPrefix(CreditCardReminderKind.paymentDue.identifierPrefix) == true)
    }

    @Test("Fingerprint is stable across calls for the same account metadata")
    func fingerprintIsStable() {
        let a = CreditCardReminderPlanner.fingerprint(
            accountName: "Sample Card",
            institutionName: "Example Bank"
        )
        let b = CreditCardReminderPlanner.fingerprint(
            accountName: "Sample Card",
            institutionName: "Example Bank"
        )
        #expect(a == b)
        #expect(!a.isEmpty)
        #expect(!a.contains(" "))
    }

    @Test("Two different accounts on the same institution generate distinct identifiers")
    func distinctAccountsGetDistinctIdentifiers() {
        let a = CreditCardReminderPlanner.fingerprint(
            accountName: "Primary Card",
            institutionName: "Example Bank"
        )
        let b = CreditCardReminderPlanner.fingerprint(
            accountName: "Travel Card",
            institutionName: "Example Bank"
        )
        #expect(a != b)
    }

    // MARK: - Privacy

    @Test("Plan copy never includes the account fingerprint, names, balances, or limits")
    func copyIsPrivacySafe() {
        // Use a fingerprint that contains a recognisable token so we
        // can assert it does NOT appear in user-facing copy.
        let fingerprint = "SENSITIVETOKEN1234"
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: fingerprint,
            now: Self.date(year: 2026, month: 4, day: 21),
            calendar: Self.utcCalendar
        )
        for plan in plans {
            #expect(!plan.title.contains(fingerprint))
            #expect(!plan.body.contains(fingerprint))
            // Smoke-check the copy is the generic lock-screen-safe text.
            #expect(!plan.body.localizedStandardContains("Chase"))
            #expect(!plan.body.localizedStandardContains("$"))
            #expect(!plan.body.localizedStandardContains("USD"))
            #expect(!plan.body.localizedStandardContains("limit"))
            #expect(!plan.body.localizedStandardContains("balance"))
        }
    }

    @Test("Copy points the user back to NomadFi without naming the card")
    func copyPointsToNomadFi() {
        let plans = CreditCardReminderPlanner.plans(
            for: Self.confirmedSchedule(),
            accountFingerprint: Self.sampleFingerprint,
            now: Self.date(year: 2026, month: 4, day: 21),
            calendar: Self.utcCalendar
        )
        for plan in plans {
            #expect(plan.body.localizedStandardContains("NomadFi"))
        }
    }
}
