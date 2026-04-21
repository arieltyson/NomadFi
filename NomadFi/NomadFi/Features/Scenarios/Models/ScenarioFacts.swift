// ScenarioFacts.swift
// NomadFi
//
// The numeric facts that drive Scenario 1's decision brief. Values are
// taken from the checkout screenshots captured on 2026-04-21 and from
// Ariel's testbed in `docs/ARIEL.md`. All math here is pure so that
// tests can pin the specific ratios the UI advertises to the user.

import Foundation

/// Numeric inputs to the Amazon.com arrival-order decision brief.
///
/// The concrete Scenario 1 values live in ``ScenarioFacts/scenario1``;
/// tests can still construct arbitrary instances to pin ratios.
struct ScenarioFacts: Sendable, Equatable {

    // MARK: - Amazon checkout

    /// Pay-in-USD checkout total shown at Amazon checkout.
    let usdCheckoutAmount: Double
    /// Amazon Currency Converter total shown when paying in CAD.
    let accCadTotal: Double
    /// Explicit "exchange rate guarantee fee" line in the ACC breakdown.
    let accExplicitFeeCAD: Double
    /// Amazon's own displayed conversion rate (CAD per USD).
    let amazonDisplayedRateCADperUSD: Double

    // MARK: - Chase Freedom Rise (Ariel)

    /// Total credit limit. Phase 3 does not know available credit.
    let chaseTotalCreditLimitUSD: Double
    /// Chase Freedom Rise purchase APR shown on `docs/ARIEL.md`.
    let chasePurchaseAPRPercent: Double

    // MARK: - Derived values (pure)

    /// Pre-fee CAD amount implied by Amazon's own displayed rate:
    /// `usdCheckoutAmount × amazonDisplayedRateCADperUSD`.
    var preACCFeeCAD: Double {
        usdCheckoutAmount * amazonDisplayedRateCADperUSD
    }

    /// ACC fee as a share of the pre-fee CAD amount (not of the USD
    /// amount — comparing CAD to USD is a unit error).
    ///
    /// For Scenario 1: `13.00 / 467.84 ≈ 0.02778` → **2.78%**.
    var accFeePercentOfPreFeeCAD: Double {
        guard preACCFeeCAD > 0 else { return 0 }
        return accExplicitFeeCAD / preACCFeeCAD
    }

    /// The all-in effective rate implied by ACC: `accCadTotal / usdCheckoutAmount`.
    ///
    /// For Scenario 1: `480.86 / 342.67 ≈ 1.4032 CAD/USD`.
    var accEffectiveRateCADperUSD: Double {
        guard usdCheckoutAmount > 0 else { return 0 }
        return accCadTotal / usdCheckoutAmount
    }

    /// Chase utilization ratio for this purchase, given a current
    /// statement balance the caller must supply or explicitly assume
    /// zero. Returns `nil` when the limit is non-positive.
    ///
    /// - Parameter currentBalanceUSD: The caller-supplied statement
    ///   balance. Pass `0` only as an explicit assumption; otherwise
    ///   ask the user.
    func chaseUtilizationPercent(currentBalanceUSD: Double) -> Double? {
        guard chaseTotalCreditLimitUSD > 0 else { return nil }
        return (currentBalanceUSD + usdCheckoutAmount) / chaseTotalCreditLimitUSD
    }
}

// MARK: - Scenario 1 fixture

extension ScenarioFacts {

    /// The immutable Scenario 1 fixture for Ariel's Amazon.com arrival
    /// order (values from `docs/ARIEL.md` §4 → Scenario 1).
    static let scenario1 = ScenarioFacts(
        usdCheckoutAmount: 342.67,
        accCadTotal: 480.86,
        accExplicitFeeCAD: 13.00,
        amazonDisplayedRateCADperUSD: 1.36528,
        chaseTotalCreditLimitUSD: 500,
        chasePurchaseAPRPercent: 25.24
    )
}
