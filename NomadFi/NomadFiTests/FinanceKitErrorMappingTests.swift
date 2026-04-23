// FinanceKitErrorMappingTests.swift
// NomadFi
//
// Phase 5C coverage for how ``FinanceKitFinancialDataProvider``
// translates Apple's ``FinanceError`` cases into NomadFi's
// provider-neutral authorization / error surface. Tests are pure
// static-call assertions; no FinanceKit framework state or managed
// entitlement is touched.

import FinanceKit
import Foundation
import Testing

@testable import NomadFi

struct FinanceKitErrorMappingTests {

    // MARK: - Authorization enum mapping

    @Test("FinanceKit authorization enum round-trips into the provider-neutral enum")
    func authorizationEnumMapping() {
        #expect(FinanceKitFinancialDataProvider.map(.authorized) == .authorized)
        #expect(FinanceKitFinancialDataProvider.map(.denied) == .denied)
        #expect(FinanceKitFinancialDataProvider.map(.notDetermined) == .notDetermined)
    }

    // MARK: - FinanceError → authorization

    @Test("FinanceError.dataRestricted collapses into the calm unavailable surface")
    func dataRestrictedMapsToUnavailable() {
        let authorization = FinanceKitFinancialDataProvider.authorizationStatus(
            for: .dataRestricted(.financialData)
        )
        #expect(authorization == .unavailable)
    }

    @Test("FinanceError.unknown stays unavailable — never silently authorized")
    func unknownErrorStaysUnavailable() {
        let authorization = FinanceKitFinancialDataProvider.authorizationStatus(
            for: .unknown
        )
        #expect(authorization == .unavailable)
    }

    // MARK: - FinanceError → provider error

    @Test("FinanceError.dataRestricted produces entitlementNotProvisioned on the provider error")
    func dataRestrictedMapsToEntitlementError() {
        let error = FinanceKitFinancialDataProvider.providerError(
            for: .dataRestricted(.financialData)
        )
        #expect(error == .providerUnavailable(.entitlementNotProvisioned))
    }

    @Test("FinanceError.unknown produces a refreshFailed — the user can retry")
    func unknownMapsToRefreshFailed() {
        let error = FinanceKitFinancialDataProvider.providerError(
            for: .unknown
        )
        #expect(error == .refreshFailed)
    }
}
