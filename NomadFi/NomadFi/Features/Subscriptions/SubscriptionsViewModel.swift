// SubscriptionsViewModel.swift
// NomadFi
//
// Manages subscription detection, comparison, and display state.
// Coordinates between the detection engine, comparison engine,
// and SwiftData persistence.

import Foundation
import OSLog
import SwiftData

/// Manages Subscriptions feature state and coordinates business logic.
///
/// Orchestrates subscription detection via ``SubscriptionDetector``,
/// cross-border price comparison via ``SubscriptionComparisonEngine``,
/// and persists confirmed subscriptions to SwiftData.
@MainActor
@Observable
final class SubscriptionsViewModel {

    // MARK: - State

    var detectedSubscriptions: [SubscriptionDetector.DetectedSubscription] = []
    var comparisonResults: [SubscriptionComparisonEngine.ComparisonResult] = []
    var isDetecting = false
    var isComparing = false
    var searchText = ""
    var errorMessage: String?

    // MARK: - Dependencies

    private let services: ServiceContainer
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Subscriptions")

    init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
    }

    // MARK: - Detection

    /// Scans transactions for recurring subscription patterns.
    ///
    /// Filters out already-tracked subscriptions and presents only
    /// new candidates for the user to confirm.
    func detectSubscriptions(
        transactions: [Transaction],
        existingSubscriptions: [Subscription]
    ) {
        isDetecting = true
        defer { isDetecting = false }

        let candidates = SubscriptionDetector.detect(from: transactions)
        detectedSubscriptions = candidates.filter { candidate in
            !SubscriptionDetector.isAlreadyTracked(candidate, existing: existingSubscriptions)
        }

        Self.logger.info("Found \(self.detectedSubscriptions.count) new subscription candidates")
    }

    /// Saves a detected subscription to SwiftData.
    func confirmSubscription(
        _ detection: SubscriptionDetector.DetectedSubscription,
        modelContext: ModelContext
    ) {
        let subscription = Subscription(
            serviceName: detection.merchantName,
            amount: detection.amount,
            currencyCode: detection.currencyCode,
            frequency: detection.frequency,
            nextRenewalDate: detection.nextEstimatedDate,
            jurisdiction: detection.jurisdiction,
            detectedAt: .now
        )
        modelContext.insert(subscription)

        // Remove from detected list
        detectedSubscriptions.removeAll {
            $0.merchantName == detection.merchantName && $0.amount == detection.amount
        }

        Self.logger.info("Subscription confirmed: \(detection.merchantName)")
    }

    /// Dismisses a detection candidate.
    func dismissDetection(_ detection: SubscriptionDetector.DetectedSubscription) {
        detectedSubscriptions.removeAll {
            $0.merchantName == detection.merchantName && $0.amount == detection.amount
        }
    }

    // MARK: - Comparison

    /// Compares subscriptions across jurisdictions to find savings.
    func compareSubscriptions(
        subscriptions: [Subscription],
        jurisdictions: [JurisdictionProfile],
        homeCurrency: CurrencyCode
    ) async {
        isComparing = true
        defer { isComparing = false }

        do {
            let currencies = jurisdictions.compactMap(\.currencyCode)
            let rates = try await services.exchangeRateService.fetchAllRates(for: currencies)

            comparisonResults = SubscriptionComparisonEngine.compareAll(
                subscriptions: subscriptions,
                jurisdictions: jurisdictions,
                exchangeRates: rates,
                homeCurrency: homeCurrency
            )

            // Update subscription records with cheapest alternative info
            for result in comparisonResults {
                if let subscription = subscriptions.first(where: {
                    $0.serviceName.localizedStandardContains(result.serviceName)
                }) {
                    subscription.cheapestAlternativeAmount = result.cheapestAmount
                    subscription.cheapestAlternativeCurrencyRawValue = result.cheapestCurrency.rawValue
                    subscription.cheapestAlternativeJurisdiction = result.cheapestJurisdiction
                    subscription.homeCurrencyEquivalent = result.currentAmount
                }
            }

            Self.logger.info("Comparison complete: \(self.comparisonResults.count) savings found")
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Comparison failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed Properties

    /// Total potential annual savings across all subscriptions.
    var totalAnnualSavings: Double {
        SubscriptionComparisonEngine.totalAnnualSavings(comparisonResults)
    }

    /// Total monthly subscription cost.
    func totalMonthlyCost(_ subscriptions: [Subscription]) -> Double {
        subscriptions.reduce(0) { total, subscription in
            guard let frequency = subscription.frequency else { return total }
            let monthly = subscription.amount / (frequency.annualizedMultiplier / 12)
            return total + monthly
        }
    }

    /// Filters subscriptions by search text.
    func filteredSubscriptions(_ subscriptions: [Subscription]) -> [Subscription] {
        guard !searchText.isEmpty else { return subscriptions }
        return subscriptions.filter {
            $0.serviceName.localizedStandardContains(searchText)
        }
    }

    /// Determines the home currency from jurisdiction profiles.
    func homeCurrency(from jurisdictions: [JurisdictionProfile]) -> CurrencyCode {
        jurisdictions.first { $0.isHome }?.currencyCode ?? .usd
    }

    // MARK: - Deletion

    /// Deletes a subscription from SwiftData.
    func deleteSubscription(_ subscription: Subscription, modelContext: ModelContext) {
        modelContext.delete(subscription)
        Self.logger.info("Subscription deleted: \(subscription.serviceName)")
    }
}
