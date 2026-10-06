import Foundation
import SwiftData
import Testing
@testable import NomadFi

@MainActor
struct FiBotWorkspaceTests {
    private let today = FiBotCalendar.date("2026-10-06")!
    private func plan() -> FiBotPlan {
        var plan = FiBotPlan()
        plan.timeZoneIdentifier = "GMT"
        plan.confirmedOn = "2026-10-06"
        plan.accounts = [.init(id: "cash", name: "Synthetic cash", cash: .init(id: "cash", available: .init(1000, currency: "CAD"),
            protectedReserve: 100, observedOn: "2026-10-06", verification: .confirmed))]
        plan.coverage = .init(incomeConfirmed: true, obligationsConfirmed: true, accountsComplete: true, spendingIncluded: true, debtPaymentsIncluded: true)
        return plan
    }
    @Test func confirmedReservationsPreventAllocatingTheSameCashTwice() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        try FiBotWorkspaceStore.save(plan(), in: context)
        let purchase = FiBotPurchase(fundingAccountID: "cash", allInCost: .init(600, currency: "CAD"), costsComplete: true)
        let first = try FiBotWorkspaceStore.evaluate(question: "Synthetic purchase", purchase: purchase, in: context, now: today)
        try FiBotWorkspaceStore.reserve(first, in: context, now: today)
        #expect(throws: (any Error).self) { try FiBotWorkspaceStore.reserve(first, in: context, now: today) }
        let second = try FiBotWorkspaceStore.evaluate(question: "Another purchase", purchase: purchase, in: context, now: today)
        let result = try JSONDecoder().decode(FiBotDecision.self, from: second.decisionData)
        #expect(result.outcome == .wait)
        #expect(result.maximumNow?.amount == 300)
    }
    @Test func evaluationAndReservationUseTheSavedPlanDay() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        var plan = plan()
        plan.timeZoneIdentifier = "America/Vancouver"
        plan.confirmedOn = "2026-10-05"
        plan.accounts[0].cash.observedOn = "2026-10-05"
        try FiBotWorkspaceStore.save(plan, in: context)
        let record = try FiBotWorkspaceStore.evaluate(question: "Synthetic", purchase: .init(fundingAccountID: "cash",
            allInCost: .init(10, currency: "CAD"), costsComplete: true), in: context, now: today)
        let snapshot = try JSONDecoder().decode(FiBotFinancialContext.self, from: record.contextData)
        #expect(snapshot.evaluatedOn == "2026-10-05")
        try FiBotWorkspaceStore.reserve(record, in: context, now: today)
        #expect(try FiBotWorkspaceStore.load(in: context).0.commitments.first?.expiresOn == "2026-10-12")
    }

    @Test func purchaseCurrencyCannotBeRelabeledAsTheFundingCurrency() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        try FiBotWorkspaceStore.save(plan(), in: context)
        let record = try FiBotWorkspaceStore.evaluate(question: "Synthetic USD purchase", purchase: .init(fundingAccountID: "cash",
            allInCost: .init(10, currency: "USD"), costsComplete: true), in: context, now: today)
        let decision = try JSONDecoder().decode(FiBotDecision.self, from: record.decisionData)
        #expect(decision.outcome == .needsMoreInformation)
        #expect(throws: (any Error).self) { try FiBotWorkspaceStore.reserve(record, in: context, now: today) }
    }
    @Test func expiredDecisionsCannotReserveAndErasureIncludesHistory() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        try FiBotWorkspaceStore.save(plan(), in: context)
        let record = try FiBotWorkspaceStore.evaluate(question: "Synthetic", purchase: .init(fundingAccountID: "cash", allInCost: .init(10, currency: "CAD"), costsComplete: true), in: context, now: today)
        #expect(throws: (any Error).self) { try FiBotWorkspaceStore.reserve(record, in: context, now: today.addingTimeInterval(3601)) }
        try FiBotWorkspaceStore.erase(in: context)
        #expect(try context.fetchCount(FetchDescriptor<FiBotWorkspace>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<FiBotDecisionRecord>()) == 0)
    }
    @Test func malformedSavedPlansAreNeverSilentlyReplaced() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        context.insert(FiBotWorkspace(planData: Data("broken".utf8)))
        try context.save()
        #expect(throws: (any Error).self) { try FiBotWorkspaceStore.save(plan(), in: context) }
        #expect(try context.fetch(FetchDescriptor<FiBotWorkspace>()).first?.planData == Data("broken".utf8))
    }
    @Test func versionTwoDiskStorePreservesBankRecordsAndAddsFiBot() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "migration.store")
        try autoreleasepool {
            let schema = Schema(versionedSchema: NomadFiSchemaV2.self)
            let old = try ModelContainer(for: schema, configurations: .init(schema: schema, url: url, cloudKitDatabase: .none))
            let context = ModelContext(old)
            context.insert(Account(name: "Preserved account", currencyCode: .cad)); try context.save()
        }
        let schema = Schema(versionedSchema: NomadFiSchemaV3.self)
        let migrated = try ModelContainer(for: schema, migrationPlan: NomadFiMigrationPlan.self,
            configurations: .init(schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(migrated)
        #expect(try context.fetch(FetchDescriptor<Account>()).first?.name == "Preserved account")
        try FiBotWorkspaceStore.save(plan(), in: context)
        #expect(try context.fetchCount(FetchDescriptor<FiBotWorkspace>()) == 1)
    }
}
