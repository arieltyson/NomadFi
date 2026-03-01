// SubscriptionComparisonEngine.swift
// NomadFi
//
// Compares subscription costs across jurisdictions to identify
// cross-border pricing arbitrage opportunities.

import Foundation
import OSLog

/// Compares subscription pricing across the user's jurisdictions to find savings.
///
/// Uses known service pricing data and exchange rates to determine whether
/// keeping a subscription in a different country is cheaper. This is the core
/// engine behind NomadFi's "Subscription Arbitrage" feature.
///
/// - Note: All methods are `@MainActor` because they access SwiftData
///   `@Model` objects and are called from main-actor-isolated view models.
enum SubscriptionComparisonEngine {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "SubscriptionComparison")

    /// The result of comparing a subscription across jurisdictions.
    struct ComparisonResult: Sendable, Identifiable {
        let id = UUID()
        let serviceName: String
        let currentAmount: Double
        let currentCurrency: CurrencyCode
        let currentJurisdiction: String
        let cheapestAmount: Double
        let cheapestCurrency: CurrencyCode
        let cheapestJurisdiction: String
        let monthlySavingsInHomeCurrency: Double
        let annualSavingsInHomeCurrency: Double
        let homeCurrency: CurrencyCode
    }

    // MARK: - Public API

    /// Compares all subscriptions against known pricing in other jurisdictions.
    ///
    /// For each subscription, looks up the known price in the user's other
    /// jurisdictions and converts to home currency using current rates.
    ///
    /// - Parameters:
    ///   - subscriptions: The user's detected subscriptions.
    ///   - jurisdictions: The user's configured jurisdictions.
    ///   - exchangeRates: Current exchange rate snapshots.
    ///   - homeCurrency: The user's home currency for comparison.
    /// - Returns: Comparison results for subscriptions with savings potential.
    @MainActor
    static func compareAll(
        subscriptions: [Subscription],
        jurisdictions: [JurisdictionProfile],
        exchangeRates: [ExchangeRateSnapshot],
        homeCurrency: CurrencyCode
    ) -> [ComparisonResult] {
        var results: [ComparisonResult] = []

        for subscription in subscriptions {
            guard let currency = subscription.currencyCode,
                  let frequency = subscription.frequency
            else { continue }

            // Find alternative pricing in other jurisdictions
            let alternatives = findAlternativePricing(
                serviceName: subscription.serviceName,
                currentJurisdiction: subscription.jurisdiction,
                jurisdictions: jurisdictions
            )

            // Convert all prices to home currency for comparison
            let currentMonthly = monthlyAmount(
                subscription.amount,
                frequency: frequency
            )
            let currentInHome = convert(
                currentMonthly,
                from: currency,
                to: homeCurrency,
                rates: exchangeRates
            )

            var cheapestAlternative: (amount: Double, currency: CurrencyCode, jurisdiction: String)?

            for alternative in alternatives {
                let alternativeMonthly = monthlyAmount(
                    alternative.amount,
                    frequency: frequency
                )
                let alternativeInHome = convert(
                    alternativeMonthly,
                    from: alternative.currency,
                    to: homeCurrency,
                    rates: exchangeRates
                )

                if let current = cheapestAlternative {
                    let currentCheapest = convert(
                        monthlyAmount(current.amount, frequency: frequency),
                        from: current.currency,
                        to: homeCurrency,
                        rates: exchangeRates
                    )
                    if alternativeInHome < currentCheapest {
                        cheapestAlternative = (alternative.amount, alternative.currency, alternative.jurisdiction)
                    }
                } else if alternativeInHome < currentInHome {
                    cheapestAlternative = (alternative.amount, alternative.currency, alternative.jurisdiction)
                }
            }

            if let cheapest = cheapestAlternative {
                let cheapestMonthly = monthlyAmount(cheapest.amount, frequency: frequency)
                let cheapestInHome = convert(
                    cheapestMonthly,
                    from: cheapest.currency,
                    to: homeCurrency,
                    rates: exchangeRates
                )
                let monthlySavings = currentInHome - cheapestInHome

                if monthlySavings > 0.10 {
                    results.append(ComparisonResult(
                        serviceName: subscription.serviceName,
                        currentAmount: subscription.amount,
                        currentCurrency: currency,
                        currentJurisdiction: subscription.jurisdiction,
                        cheapestAmount: cheapest.amount,
                        cheapestCurrency: cheapest.currency,
                        cheapestJurisdiction: cheapest.jurisdiction,
                        monthlySavingsInHomeCurrency: monthlySavings,
                        annualSavingsInHomeCurrency: monthlySavings * 12,
                        homeCurrency: homeCurrency
                    ))
                }
            }
        }

        let sorted = results.sorted { $0.annualSavingsInHomeCurrency > $1.annualSavingsInHomeCurrency }
        logger.info("Found \(sorted.count) subscription savings opportunities")
        return sorted
    }

    /// Calculates the aggregate annual savings across all comparison results.
    static func totalAnnualSavings(_ results: [ComparisonResult]) -> Double {
        results.reduce(0) { $0 + $1.annualSavingsInHomeCurrency }
    }

    // MARK: - Known Pricing Data

    /// Known pricing for popular services across jurisdictions.
    ///
    /// Stored as (jurisdiction, amount, currency) tuples. In a production app,
    /// this could be fetched from a backend or crowdsourced from users.
    private struct AlternativePrice {
        let amount: Double
        let currency: CurrencyCode
        let jurisdiction: String
    }

    private static func findAlternativePricing(
        serviceName: String,
        currentJurisdiction: String,
        jurisdictions: [JurisdictionProfile]
    ) -> [AlternativePrice] {
        let normalized = serviceName.lowercased()
        let otherJurisdictions = jurisdictions.filter { $0.countryCode != currentJurisdiction }

        guard let knownPricing = knownServicePricing[normalized] else {
            return []
        }

        return otherJurisdictions.compactMap { jurisdiction in
            guard let pricing = knownPricing[jurisdiction.countryCode] else { return nil }
            return AlternativePrice(
                amount: pricing.amount,
                currency: pricing.currency,
                jurisdiction: jurisdiction.countryCode
            )
        }
    }

    /// Known monthly pricing for popular services by jurisdiction.
    ///
    /// Format: `[normalizedServiceName: [jurisdictionCode: (amount, currency)]]`
    private static let knownServicePricing: [String: [String: (amount: Double, currency: CurrencyCode)]] = [
        "netflix": [
            "US": (amount: 15.49, currency: .usd),
            "CA": (amount: 16.99, currency: .cad),
            "GB": (amount: 10.99, currency: .gbp),
            "TT": (amount: 104.99, currency: .ttd),
        ],
        "spotify": [
            "US": (amount: 11.99, currency: .usd),
            "CA": (amount: 11.99, currency: .cad),
            "GB": (amount: 10.99, currency: .gbp),
            "TT": (amount: 29.99, currency: .ttd),
        ],
        "apple music": [
            "US": (amount: 10.99, currency: .usd),
            "CA": (amount: 10.99, currency: .cad),
            "GB": (amount: 10.99, currency: .gbp),
            "TT": (amount: 4.99, currency: .usd),
        ],
        "youtube premium": [
            "US": (amount: 13.99, currency: .usd),
            "CA": (amount: 13.99, currency: .cad),
            "GB": (amount: 12.99, currency: .gbp),
            "TT": (amount: 11.99, currency: .usd),
        ],
        "disney+": [
            "US": (amount: 13.99, currency: .usd),
            "CA": (amount: 11.99, currency: .cad),
            "GB": (amount: 7.99, currency: .gbp),
        ],
        "amazon prime": [
            "US": (amount: 14.99, currency: .usd),
            "CA": (amount: 9.99, currency: .cad),
            "GB": (amount: 8.99, currency: .gbp),
        ],
        "chatgpt plus": [
            "US": (amount: 20.00, currency: .usd),
            "CA": (amount: 20.00, currency: .usd),
            "GB": (amount: 20.00, currency: .usd),
        ],
        "icloud+": [
            "US": (amount: 2.99, currency: .usd),
            "CA": (amount: 3.99, currency: .cad),
            "GB": (amount: 2.99, currency: .gbp),
        ],
    ]

    // MARK: - Conversion Helpers

    private static func monthlyAmount(_ amount: Double, frequency: BillingFrequency) -> Double {
        switch frequency {
        case .weekly: amount * 52 / 12
        case .monthly: amount
        case .quarterly: amount / 3
        case .annual: amount / 12
        }
    }

    private static func convert(
        _ amount: Double,
        from source: CurrencyCode,
        to target: CurrencyCode,
        rates: [ExchangeRateSnapshot]
    ) -> Double {
        guard source != target else { return amount }

        if let directRate = rates.first(where: { $0.baseCurrency == source && $0.targetCurrency == target }) {
            return amount * directRate.rate
        }

        // Try inverse rate
        if let inverseRate = rates.first(where: { $0.baseCurrency == target && $0.targetCurrency == source }),
           inverseRate.rate > 0
        {
            return amount / inverseRate.rate
        }

        // Fallback: return amount unchanged (best effort)
        return amount
    }
}
