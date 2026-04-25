// JurisdictionHomeRepairPlanTests.swift
// NomadFi
//
// Pins the repair-planner contract in pure value terms — no
// SwiftData container required. The planner is the single source
// of truth that both `SettingsView` and `JurisdictionManager` use
// to decide whether to collapse the home-flag set; both tests
// here and the existing `JurisdictionManagerTests` exercise the
// same rule from different angles.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct JurisdictionHomeRepairPlanTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    @discardableResult
    private func makeProfile(
        in context: ModelContext,
        countryCode: String,
        countryName: String = "",
        isHome: Bool = false,
        displayOrder: Int = 0,
        createdAt: Date = .now
    ) -> JurisdictionProfile {
        let profile = JurisdictionProfile(
            countryCode: countryCode,
            countryName: countryName,
            currencyCode: .usd,
            isHome: isHome,
            displayOrder: displayOrder,
            createdAt: createdAt
        )
        context.insert(profile)
        return profile
    }

    // MARK: - Already-consistent paths

    @Test("Empty profile set is already consistent — no repair needed")
    func emptySetIsConsistent() {
        let outcome = JurisdictionHomeRepairPlan.plan(for: [])
        #expect(outcome == .alreadyConsistent)
    }

    @Test("A single profile with isHome == true is already consistent")
    func singleHomeIsConsistent() throws {
        let context = try makeContext()
        let only = makeProfile(in: context, countryCode: "CA", isHome: true)
        let outcome = JurisdictionHomeRepairPlan.plan(for: [only])
        #expect(outcome == .alreadyConsistent)
    }

    @Test("Multiple profiles with exactly one home are already consistent")
    func exactlyOneHomeIsConsistent() throws {
        let context = try makeContext()
        let profiles = [
            makeProfile(in: context, countryCode: "CA", isHome: true),
            makeProfile(in: context, countryCode: "US", isHome: false),
            makeProfile(in: context, countryCode: "GB", isHome: false),
        ]
        let outcome = JurisdictionHomeRepairPlan.plan(for: profiles)
        #expect(outcome == .alreadyConsistent)
    }

    // MARK: - Repair paths

    @Test("Zero homes with profiles present picks the earliest-created winner")
    func zeroHomesPicksEarliestCreated() throws {
        let context = try makeContext()
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let profiles = [
            makeProfile(in: context, countryCode: "GB", isHome: false, createdAt: late),
            makeProfile(in: context, countryCode: "CA", isHome: false, createdAt: early),
            makeProfile(in: context, countryCode: "US", isHome: false, createdAt: late),
        ]
        let outcome = JurisdictionHomeRepairPlan.plan(for: profiles)
        #expect(outcome == .repair(winnerCountryCode: "CA"))
    }

    @Test("Duplicate homes collapse onto the earliest-created winner")
    func duplicateHomesCollapse() throws {
        let context = try makeContext()
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let profiles = [
            makeProfile(in: context, countryCode: "US", isHome: true, createdAt: late),
            makeProfile(in: context, countryCode: "CA", isHome: true, createdAt: early),
        ]
        let outcome = JurisdictionHomeRepairPlan.plan(for: profiles)
        #expect(outcome == .repair(winnerCountryCode: "CA"))
    }

    @Test("Equal createdAt timestamps break ties by lexicographic countryCode")
    func equalTimestampsBreakOnCountryCode() throws {
        let context = try makeContext()
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let profiles = [
            makeProfile(in: context, countryCode: "US", isHome: false, createdAt: timestamp),
            makeProfile(in: context, countryCode: "CA", isHome: false, createdAt: timestamp),
            makeProfile(in: context, countryCode: "GB", isHome: false, createdAt: timestamp),
        ]
        let outcome = JurisdictionHomeRepairPlan.plan(for: profiles)
        #expect(outcome == .repair(winnerCountryCode: "CA"))
    }

    // MARK: - Determinism

    @Test("Same input always produces the same outcome (pure function)")
    func sameInputProducesSameOutcome() throws {
        let context = try makeContext()
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let profiles = [
            makeProfile(in: context, countryCode: "US", isHome: true, createdAt: late),
            makeProfile(in: context, countryCode: "CA", isHome: true, createdAt: early),
            makeProfile(in: context, countryCode: "GB", isHome: false, createdAt: late),
        ]
        let first = JurisdictionHomeRepairPlan.plan(for: profiles)
        let second = JurisdictionHomeRepairPlan.plan(for: profiles)
        let reversed = JurisdictionHomeRepairPlan.plan(for: profiles.reversed())
        #expect(first == second)
        #expect(first == reversed)
    }
}
