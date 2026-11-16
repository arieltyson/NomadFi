import Foundation
import SwiftData
import Testing
@testable import NomadFi

struct SpendingBreakdownWorkerTests {

    @Test func versionThreeDiskStoreKeepsItsDataAndGainsMerchantRules() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "migration.store")
        try autoreleasepool {
            let schema = Schema(versionedSchema: NomadFiSchemaV3.self)
            let old = try ModelContainer(for: schema, configurations: .init(schema: schema, url: url, cloudKitDatabase: .none))
            let context = ModelContext(old)
            context.insert(Transaction(merchantName: "Preserved", originalAmount: 12, originalCurrency: .cad))
            try context.save()
        }
        let schema = Schema(versionedSchema: NomadFiSchemaV4.self)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: NomadFiMigrationPlan.self,
            configurations: .init(schema: schema, url: url, cloudKitDatabase: .none)
        )
        let context = ModelContext(migrated)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).first?.merchantName == "Preserved")
        context.insert(MerchantSpendingRule(merchantKey: "EVO", subcategoryID: "transport.carShare"))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<MerchantSpendingRule>()) == 1)
    }

    @Test func splitsCategoriesAndLearnsFromARule() async throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        let purchases: [(String, Double, TransactionCategory)] = [
            ("UBER *TRIP", -20, .transport), ("Lyft", -10, .transport), ("EVO Car Share", -15, .transport),
            ("Mystery Wheels", -5, .transport), ("DOORDASH*PHO", -30, .food), ("SAFEWAY #12", -50, .food),
            ("Payroll", 1_000, .income), ("Hotel in USD", -99, .transport),
        ]
        for (name, amount, category) in purchases {
            context.insert(Transaction(
                merchantName: name,
                originalAmount: amount,
                originalCurrency: name.hasSuffix("USD") ? .usd : .cad,
                category: category
            ))
        }
        try context.save()

        let worker = SpendingBreakdownWorker(modelContainer: container)
        let first = try await worker.breakdown(period: .month, homeCurrency: .cad)
        #expect(first.total == 130)
        #expect(first.otherCurrencyCount == 1)
        #expect(first.categories.map(\.category) == [.food, .transport])

        let transport = try #require(first.slice(for: .transport))
        #expect(transport.subcategories.map(\.id) == ["transport.rideShare", "transport.carShare", "transport.other"])
        #expect(transport.subcategories.map(\.total) == [30, 15, 5])
        let food = try #require(first.slice(for: .food))
        #expect(Set(food.subcategories.map(\.id)) == ["food.groceries", "food.delivery"])

        let mystery = try #require(transport.subcategories.last?.merchants.first)
        try await worker.setRule(merchantKey: mystery.id, subcategoryID: "transport.carShare")
        let learned = try #require(try await worker.breakdown(period: .month, homeCurrency: .cad).slice(for: .transport))
        #expect(learned.subcategories.map(\.id) == ["transport.rideShare", "transport.carShare"])
        #expect(learned.subcategories.last?.total == 20)
        #expect(learned.subcategories.last?.merchants.contains { $0.ruledSubcategoryID == "transport.carShare" } == true)

        try await worker.setRule(merchantKey: mystery.id, subcategoryID: nil)
        let automatic = try #require(try await worker.breakdown(period: .month, homeCurrency: .cad).slice(for: .transport))
        #expect(automatic.subcategories.last?.isOther == true)
    }
}
