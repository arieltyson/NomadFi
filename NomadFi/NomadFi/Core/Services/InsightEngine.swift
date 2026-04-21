// InsightEngine.swift
// NomadFi
//
// Generates actionable financial insights from transaction data.
// Powers the "Your Money This Week" dashboard section with real calculations.

import Foundation
import OSLog
import SwiftData

/// Generates real-time financial insights by analyzing transactions,
/// accounts, and exchange rates.
///
/// Each insight is a specific, actionable recommendation backed by data:
/// - **FX Waste:** Detects hidden fees from cross-border transactions.
/// - **Arbitrage:** Identifies favorable exchange rate conditions.
/// - **Wrong Card:** Flags transactions where a cheaper card was available.
/// - **Budget:** Warns when spending approaches a threshold.
///
/// All methods are pure functions — no side effects, fully testable.
enum InsightEngine {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "InsightEngine")

    // MARK: - Public API

    /// Generates all applicable insights from the user's financial data.
    /// - Returns: An array of insights, sorted by priority (most urgent first).
    static func generateInsights(
        transactions: [Transaction],
        accounts: [Account],
        exchangeRates: [ExchangeRateSnapshot],
        homeCurrency: CurrencyCode
    ) -> [FinancialInsight] {
        PerformanceMonitor.measureSync(.insightEngine, name: "Generate Insights") {
            // Pre-filter to the 7-day window used by all insight generators.
            // Avoids redundant filtering of the full transaction history
            // inside each individual insight method.
            let recentWindow = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
            let recentTransactions = transactions.filter { $0.date >= recentWindow }

            var insights: [FinancialInsight] = []

            if let fxWaste = fxWasteInsight(transactions: recentTransactions, homeCurrency: homeCurrency) {
                insights.append(fxWaste)
            }

            if let wrongCard = wrongCardInsight(transactions: recentTransactions, accounts: accounts) {
                insights.append(wrongCard)
            }

            if let arbitrage = arbitrageInsight(exchangeRates: exchangeRates, homeCurrency: homeCurrency) {
                insights.append(arbitrage)
            }

            logger.info("Generated \(insights.count) insights from \(recentTransactions.count) recent transactions (of \(transactions.count) total)")
            return insights
        }
    }

    // MARK: - FX Waste Aggregation

    /// Calculates total FX waste (markup over mid-market rate) for a period.
    static func totalFXWaste(
        transactions: [Transaction],
        since startDate: Date
    ) -> Double {
        let crossBorder = transactions.filter { transaction in
            transaction.date >= startDate
                && transaction.originalCurrencyRawValue != transaction.homeCurrencyRawValue
                && transaction.midMarketRate > 0
                && transaction.appliedExchangeRate > 0
        }

        return crossBorder.reduce(0.0) { total, transaction in
            let fairCost = abs(transaction.originalAmount) * transaction.midMarketRate
            let actualCost = abs(transaction.convertedAmount)
            let markup = actualCost - fairCost
            return total + max(0, markup) // Only count overpayments
        }
    }

    /// Returns the count of cross-border transactions in a period.
    static func crossBorderTransactionCount(
        transactions: [Transaction],
        since startDate: Date
    ) -> Int {
        transactions.filter { transaction in
            transaction.date >= startDate
                && transaction.originalCurrencyRawValue != transaction.homeCurrencyRawValue
        }.count
    }
}

// MARK: - Insight Generators

private extension InsightEngine {

    /// Detects accumulated FX waste from the past 7 days.
    static func fxWasteInsight(
        transactions: [Transaction],
        homeCurrency: CurrencyCode
    ) -> FinancialInsight? {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let waste = totalFXWaste(transactions: transactions, since: oneWeekAgo)

        // Only surface if waste exceeds a meaningful threshold
        guard waste > 0.50 else { return nil }

        let formattedWaste = waste.formatted(.currency(code: homeCurrency.rawValue))
        let count = crossBorderTransactionCount(transactions: transactions, since: oneWeekAgo)

        return FinancialInsight(
            title: "Hidden FX Fees This Week",
            message: "You paid \(formattedWaste) in exchange rate markups across \(count) cross-border transaction\(count == 1 ? "" : "s"). Check which cards have the lowest foreign transaction fees.",
            category: .fxWaste,
            // Derived from user-entered transaction amounts; not a
            // verified issuer disclosure.
            confidence: .userProvided
        )
    }

    /// Detects transactions where a lower-fee card was available.
    static func wrongCardInsight(
        transactions: [Transaction],
        accounts: [Account]
    ) -> FinancialInsight? {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now

        let recentCrossBorder = transactions.filter { transaction in
            transaction.date >= oneWeekAgo
                && transaction.originalCurrencyRawValue != transaction.homeCurrencyRawValue
                && transaction.account != nil
        }

        for transaction in recentCrossBorder {
            guard let usedAccount = transaction.account else { continue }

            // Find a better card: same jurisdiction as the transaction, lower FX fee
            let betterAccount = accounts.first { candidate in
                candidate.jurisdiction == transaction.jurisdiction
                    && candidate.foreignTransactionFeePercent < usedAccount.foreignTransactionFeePercent
                    && candidate.persistentModelID != usedAccount.persistentModelID
            }

            if let better = betterAccount {
                let savings = usedAccount.foreignTransactionFeePercent - better.foreignTransactionFeePercent
                let savingsFormatted = savings.formatted(.number.precision(.fractionLength(1)))

                // Both fees must be verified *and* fresh for the savings
                // claim to read as verified. Stale or missing-date
                // verified sources are degraded to .unverified by
                // `SourceFreshness.effectiveConfidence`, which in turn
                // downgrades the whole recommendation.
                let usedEffective = SourceFreshness.effectiveConfidence(
                    for: usedAccount.foreignTransactionFeeProvenance,
                    domain: .issuerCardTerms
                )
                let betterEffective = SourceFreshness.effectiveConfidence(
                    for: better.foreignTransactionFeeProvenance,
                    domain: .issuerCardTerms
                )
                let confidence: SourceConfidence =
                    (usedEffective.isVerified && betterEffective.isVerified)
                    ? .verifiedPrimary
                    : .userProvided

                return FinancialInsight(
                    title: "Better Card Available",
                    message: "You used \(usedAccount.name) for \(transaction.merchantName) but \(better.name) has \(savingsFormatted)% lower FX fees in \(transaction.jurisdiction).",
                    category: .fxWaste,
                    confidence: confidence
                )
            }
        }

        return nil
    }

    /// Identifies favorable exchange rate conditions for money transfers.
    static func arbitrageInsight(
        exchangeRates: [ExchangeRateSnapshot],
        homeCurrency: CurrencyCode
    ) -> FinancialInsight? {
        // Find the strongest rate from a major currency to the home currency.
        // For international students, "strong USD against TTD" means it's a
        // good time to send money home.
        let homeRates = exchangeRates.filter { $0.targetCurrency == homeCurrency }

        guard let bestRate = homeRates.max(by: { $0.rate < $1.rate }) else {
            return nil
        }

        // Only surface for non-home currencies with meaningful rates
        guard bestRate.rate > 1.5 else { return nil }

        let rateFormatted = bestRate.rate.formatted(.number.precision(.fractionLength(2)))

        // Confidence is inherited from the underlying snapshot and
        // freshness-gated: a stale live rate must not claim verification.
        let effective = SourceFreshness.effectiveConfidence(
            for: bestRate.sourceProvenance,
            domain: .liveFXMarketData
        )

        return FinancialInsight(
            title: "Strong \(bestRate.baseCurrency.rawValue) Today",
            message: "1 \(bestRate.baseCurrency.rawValue) = \(rateFormatted) \(homeCurrency.rawValue). Consider sending money home to maximize your transfer value.",
            category: .arbitrage,
            confidence: effective
        )
    }
}
