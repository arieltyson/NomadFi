// ScenarioDecisionState.swift
// NomadFi
//
// Typed, user-confirmed inputs that feed the Scenario Decision Engine.
// This struct is the pure in-memory projection of `ScenarioDecisionRecord`
// — the engine and tests work against the struct, the persistence layer
// and SwiftUI bind against the record.

import Foundation

/// Pure, Sendable snapshot of the user's confirmed inputs for a scenario.
///
/// Numeric fields are optional so the engine can distinguish "user has
/// not supplied a value" from "user entered zero". Booleans default to
/// `false` so the engine never recommends a payment path on the user's
/// behalf without explicit confirmation.
struct ScenarioDecisionState: Sendable, Equatable {

    /// The user reviewed the cart for paid / overnight shipping and
    /// any accidental Subscribe & Save selections.
    var cartShippingReviewed: Bool = false

    /// The Airbnb host will receive the package, or delivery is timed
    /// for on-or-after arrival at the U.S. summer address.
    var airbnbPackageReceiptConfirmed: Bool = false

    /// User-confirmed Chase Freedom Rise available credit (USD).
    var chaseAvailableCreditUSD: Double?

    /// User-confirmed Chase Freedom Rise current statement balance (USD).
    var chaseCurrentBalanceUSD: Double?

    /// User-entered Chase statement close date — kept for context in
    /// the UI; the engine treats it as informational, not a hard input.
    var chaseStatementCloseDate: Date?

    /// The user committed to paying the Chase balance in full before
    /// the next statement closes.
    var chaseWillPayBeforeStatementClose: Bool = false

    /// User-confirmed Wise USD balance (USD).
    var wiseUSDBalanceUSD: Double?

    /// The user confirmed their Wise card is accepted by Amazon.
    var wiseCardAcceptedByAmazon: Bool = false

    init(
        cartShippingReviewed: Bool = false,
        airbnbPackageReceiptConfirmed: Bool = false,
        chaseAvailableCreditUSD: Double? = nil,
        chaseCurrentBalanceUSD: Double? = nil,
        chaseStatementCloseDate: Date? = nil,
        chaseWillPayBeforeStatementClose: Bool = false,
        wiseUSDBalanceUSD: Double? = nil,
        wiseCardAcceptedByAmazon: Bool = false
    ) {
        self.cartShippingReviewed = cartShippingReviewed
        self.airbnbPackageReceiptConfirmed = airbnbPackageReceiptConfirmed
        self.chaseAvailableCreditUSD = chaseAvailableCreditUSD
        self.chaseCurrentBalanceUSD = chaseCurrentBalanceUSD
        self.chaseStatementCloseDate = chaseStatementCloseDate
        self.chaseWillPayBeforeStatementClose = chaseWillPayBeforeStatementClose
        self.wiseUSDBalanceUSD = wiseUSDBalanceUSD
        self.wiseCardAcceptedByAmazon = wiseCardAcceptedByAmazon
    }
}

// MARK: - Bridge to persistence

extension ScenarioDecisionState {

    /// Snapshots the persisted record into a pure state value the
    /// engine can evaluate without any SwiftData dependency.
    init(record: ScenarioDecisionRecord) {
        self.init(
            cartShippingReviewed: record.cartShippingReviewed,
            airbnbPackageReceiptConfirmed: record.airbnbPackageReceiptConfirmed,
            chaseAvailableCreditUSD: record.chaseAvailableCreditUSD,
            chaseCurrentBalanceUSD: record.chaseCurrentBalanceUSD,
            chaseStatementCloseDate: record.chaseStatementCloseDate,
            chaseWillPayBeforeStatementClose: record.chaseWillPayBeforeStatementClose,
            wiseUSDBalanceUSD: record.wiseUSDBalanceUSD,
            wiseCardAcceptedByAmazon: record.wiseCardAcceptedByAmazon
        )
    }
}
