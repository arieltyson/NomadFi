import Foundation
import SwiftData
import Testing
@testable import NomadFi

struct DashboardDigestWorkerTests {

    @Test func buildsTheDigestOffTheMainActorAndRepeatsItExactly() async throws {
        let container = try ModelContainer(
            for: Transaction.self, Account.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let worker = DashboardDigestWorker(modelContainer: container)

        let empty = try await worker.digest(exchangeRates: [], homeCurrency: .cad)
        #expect(empty.insights == FinancialInsight.samples)
        #expect(empty.spendingTrend == nil)

        // Same input, same digest: the cards keep their identity, so a
        // rebuild changes nothing on screen.
        let again = try await worker.digest(exchangeRates: [], homeCurrency: .cad)
        #expect(again == empty)
        #expect(again.insights.map(\.id) == empty.insights.map(\.id))
    }
}
