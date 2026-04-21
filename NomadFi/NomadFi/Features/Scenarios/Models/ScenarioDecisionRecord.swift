// ScenarioDecisionRecord.swift
// NomadFi
//
// Persisted, user-confirmed inputs for a scenario's decision brief. One
// record exists per scenario identifier; the Scenario 1 record holds the
// numeric and boolean inputs that feed the deterministic engine.
//
// CloudKit-safe: every property has a default or is optional, and no
// `@Attribute(.unique)` is applied. Scenario uniqueness is enforced in
// application code via `ScenarioDecisionRecord.scenario1ID`.

import Foundation
import SwiftData

/// Persisted user inputs for a single scenario. The record is the source
/// of truth for Scenario 1's durable guardrail state — booleans like
/// "cart reviewed" and numeric inputs like Chase available credit, all
/// confirmed by the user, never fetched from any issuer.
@Model
final class ScenarioDecisionRecord {

    /// Stable identifier for the scenario this record belongs to. Kept
    /// optional-safe via default value so CloudKit can materialize new
    /// records without violating schema requirements.
    var scenarioID: String = ""

    /// The user confirmed they reviewed cart shipping and Subscribe &
    /// Save lines before choosing a payment method.
    var cartShippingReviewed: Bool = false

    /// The user confirmed the Airbnb host will accept the package, or
    /// the delivery is timed to land after arrival.
    var airbnbPackageReceiptConfirmed: Bool = false

    /// User-entered Chase Freedom Rise available credit (USD). `nil`
    /// means the user has not supplied a value yet — the engine must
    /// refuse to recommend Chase until this is set.
    var chaseAvailableCreditUSD: Double?

    /// User-entered Chase Freedom Rise current statement balance (USD).
    /// Required to compute projected utilization honestly — without it
    /// the engine falls back to the zero-balance reference only.
    var chaseCurrentBalanceUSD: Double?

    /// Legacy, scenario-local Chase statement close date. Retained for
    /// migration safety — the engine now prefers the statement close
    /// date on the linked ``chasePaymentAccount``. New edits flow
    /// through Settings → Credit Card Calendar.
    var chaseStatementCloseDate: Date?

    /// The persisted credit-card account the user has linked as their
    /// Chase Freedom Rise. `.nullify` means scenario inputs survive a
    /// card deletion as plain boolean/numeric values without being
    /// force-cascaded into an orphaned state.
    @Relationship(deleteRule: .nullify)
    var chasePaymentAccount: Account?

    /// The user committed to paying the Chase balance in full before
    /// the next statement closes. Gates Chase recommendation.
    var chaseWillPayBeforeStatementClose: Bool = false

    /// User-entered Wise USD balance (USD). `nil` means the user has
    /// not supplied a value yet — the engine must refuse to recommend
    /// Wise until this is set.
    var wiseUSDBalanceUSD: Double?

    /// The user confirmed their Wise card is accepted by Amazon for
    /// this order. Defaults to `false` because Amazon acceptance varies
    /// by card BIN and must be user-verified.
    var wiseCardAcceptedByAmazon: Bool = false

    /// Timestamp of the most recent input edit. Updated by the view
    /// model on every persistence cycle so the UI and future analytics
    /// can reason about staleness.
    var updatedAt: Date = Date.now

    init(
        scenarioID: String = "",
        cartShippingReviewed: Bool = false,
        airbnbPackageReceiptConfirmed: Bool = false,
        chaseAvailableCreditUSD: Double? = nil,
        chaseCurrentBalanceUSD: Double? = nil,
        chaseStatementCloseDate: Date? = nil,
        chasePaymentAccount: Account? = nil,
        chaseWillPayBeforeStatementClose: Bool = false,
        wiseUSDBalanceUSD: Double? = nil,
        wiseCardAcceptedByAmazon: Bool = false,
        updatedAt: Date = .now
    ) {
        self.scenarioID = scenarioID
        self.cartShippingReviewed = cartShippingReviewed
        self.airbnbPackageReceiptConfirmed = airbnbPackageReceiptConfirmed
        self.chaseAvailableCreditUSD = chaseAvailableCreditUSD
        self.chaseCurrentBalanceUSD = chaseCurrentBalanceUSD
        self.chaseStatementCloseDate = chaseStatementCloseDate
        self.chasePaymentAccount = chasePaymentAccount
        self.chaseWillPayBeforeStatementClose = chaseWillPayBeforeStatementClose
        self.wiseUSDBalanceUSD = wiseUSDBalanceUSD
        self.wiseCardAcceptedByAmazon = wiseCardAcceptedByAmazon
        self.updatedAt = updatedAt
    }
}

// MARK: - Identifiers

extension ScenarioDecisionRecord {

    /// Stable identifier for Scenario 1 (Amazon.com arrival order).
    static let scenario1ID: String = "scenario-amazon-arrival-order"
}
