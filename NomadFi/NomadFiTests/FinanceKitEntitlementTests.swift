// FinanceKitEntitlementTests.swift
// NomadFi
//
// Pins the entitlement-gate invariant that stops the FinanceKit
// adapter from entering `FinanceStore` symbols on a device that
// does not carry `com.apple.developer.financekit`. Missing this
// guard previously triggered an uncatchable
// "Process is not entitled" runtime abort the moment the Financial
// Connections page appeared — regression-covered here.

import Foundation
import Testing

@testable import NomadFi

struct FinanceKitEntitlementTests {

    // MARK: - Provider short-circuit

    @Test("availability() reports entitlementNotProvisioned when the entitlement is absent")
    func availabilityShortCircuitsWithoutEntitlement() async {
        FinanceKitEntitlement.testOverride = false
        defer { FinanceKitEntitlement.testOverride = nil }

        let provider = FinanceKitFinancialDataProvider()
        let availability = await provider.availability()
        #expect(availability == .unavailable(reason: .entitlementNotProvisioned))
    }

    @Test("authorizationStatus() returns .unavailable without touching FinanceStore")
    func authorizationStatusUnavailableWithoutEntitlement() async {
        FinanceKitEntitlement.testOverride = false
        defer { FinanceKitEntitlement.testOverride = nil }

        let provider = FinanceKitFinancialDataProvider()
        let status = await provider.authorizationStatus()
        #expect(status == .unavailable)
    }

    @Test("requestAuthorization() throws providerUnavailable(.entitlementNotProvisioned)")
    func requestAuthorizationThrowsWithoutEntitlement() async {
        FinanceKitEntitlement.testOverride = false
        defer { FinanceKitEntitlement.testOverride = nil }

        let provider = FinanceKitFinancialDataProvider()
        do {
            _ = try await provider.requestAuthorization()
            Issue.record("Expected requestAuthorization to throw")
        } catch let error as FinancialDataProviderError {
            #expect(error == .providerUnavailable(.entitlementNotProvisioned))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("fetchAccountSnapshots() throws instead of aborting when entitlement is missing")
    func fetchAccountsShortCircuits() async {
        FinanceKitEntitlement.testOverride = false
        defer { FinanceKitEntitlement.testOverride = nil }

        let provider = FinanceKitFinancialDataProvider()
        do {
            _ = try await provider.fetchAccountSnapshots()
            Issue.record("Expected fetchAccountSnapshots to throw")
        } catch let error as FinancialDataProviderError {
            #expect(error == .providerUnavailable(.entitlementNotProvisioned))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("fetchTransactionSnapshots() throws instead of aborting when entitlement is missing")
    func fetchTransactionsShortCircuits() async {
        FinanceKitEntitlement.testOverride = false
        defer { FinanceKitEntitlement.testOverride = nil }

        let provider = FinanceKitFinancialDataProvider()
        do {
            _ = try await provider.fetchTransactionSnapshots(
                accountID: UUID().uuidString,
                from: Date(timeIntervalSince1970: 0),
                to: Date(timeIntervalSince1970: 1)
            )
            Issue.record("Expected fetchTransactionSnapshots to throw")
        } catch let error as FinancialDataProviderError {
            #expect(error == .providerUnavailable(.entitlementNotProvisioned))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Entitlement value shape

    @Test("Entitlement constants match Apple's documented keys")
    func entitlementConstants() {
        #expect(FinanceKitEntitlement.entitlementKey == "com.apple.developer.financekit")
        #expect(FinanceKitEntitlement.financialDataPermission == "financial-data")
    }
}
