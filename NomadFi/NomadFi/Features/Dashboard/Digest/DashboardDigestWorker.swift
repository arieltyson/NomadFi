import Foundation
import SwiftData

/// Reads the whole transaction history in its own model context, off the
/// main thread, and condenses it into a ``DashboardDigest``.
///
/// The Dashboard used to fetch every transaction on the main actor and run
/// the insight and trend engines there, which froze scrolling and the
/// pull-to-refresh animation for as long as the work took. Only the small,
/// `Sendable` digest crosses back to the UI.
@ModelActor
actor DashboardDigestWorker {

    /// Builds the digest from the rows currently saved in the store.
    func digest(
        exchangeRates: [ExchangeRateSnapshot],
        homeCurrency: CurrencyCode,
        now: Date = .now
    ) throws -> DashboardDigest {
        let transactions = try modelContext.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
        let accounts = try modelContext.fetch(FetchDescriptor<Account>())

        let generated = InsightEngine.generateInsights(
            transactions: transactions,
            accounts: accounts,
            exchangeRates: exchangeRates,
            homeCurrency: homeCurrency,
            now: now
        )

        return DashboardDigest(
            // With no history yet, show what the section is for instead
            // of leaving it empty.
            insights: generated.isEmpty && transactions.isEmpty ? FinancialInsight.samples : generated,
            spendingTrend: SpendingTrendComputer.summary(
                transactions: transactions,
                now: now,
                homeCurrency: homeCurrency
            )
        )
    }
}
