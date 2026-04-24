// PlaidSandboxConfigurationTests.swift
// NomadFi
//
// Narrow coverage that the Plaid sandbox configuration never leaks
// Plaid `client_id` / `secret` into the app side, and that the
// broker URL / item handle / cursor round-trip through the storage
// seam. Uses an in-memory stub so no test touches the real Keychain.
//
// Also pins the "copy guard" for the Plaid sandbox's provider kind
// logKey + display label so the Settings page never accidentally
// starts claiming coverage the sandbox does not have.

import Foundation
import Testing

@testable import NomadFi

struct PlaidSandboxConfigurationTests {

    // MARK: - Round-trip

    @Test("Broker URL, item handle, and cursor round-trip through the storage seam")
    func roundTripRepresentativeValues() {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)

        #expect(config.brokerURL == nil)
        #expect(config.itemID == nil)
        #expect(config.transactionsCursor == nil)

        let url = URL(string: "http://127.0.0.1:8787")!
        config.setBrokerURL(url)
        config.setItemID("itm_round_trip")
        config.setTransactionsCursor("cursor_abc_123")

        #expect(config.brokerURL == url)
        #expect(config.itemID == "itm_round_trip")
        #expect(config.transactionsCursor == "cursor_abc_123")
    }

    @Test("Empty values clear the storage slot rather than persisting empty strings")
    func emptyValuesClear() {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setItemID("itm_temp")
        config.setTransactionsCursor("cursor_temp")

        config.setItemID(nil)
        config.setTransactionsCursor("")
        config.setBrokerURL(nil)

        #expect(config.itemID == nil)
        #expect(config.transactionsCursor == nil)
        #expect(config.brokerURL == nil)
    }

    @Test("KeychainService.Key values for the Plaid sandbox are app-namespaced and stable")
    func keychainKeyNamespacesAreStable() {
        #expect(KeychainService.Key.plaidSandboxBrokerURL.rawValue == "com.nomadfi.plaidSandboxBrokerURL")
        #expect(KeychainService.Key.plaidSandboxItemID.rawValue == "com.nomadfi.plaidSandboxItemID")
        #expect(KeychainService.Key.plaidSandboxTransactionsCursor.rawValue == "com.nomadfi.plaidSandboxTransactionsCursor")
    }

    // MARK: - Copy guard

    @Test("The sandbox provider's display label never claims production-style coverage")
    func displayLabelIsHonestlySandbox() {
        let kind = FinancialDataProviderKind.externalAggregator(identifier: "plaid_sandbox")
        let label = kind.displayLabel.lowercased()
        let forbidden = [
            "all your banks",
            "all your cards",
            "every institution",
            "instant sync everywhere",
            "automatic for every institution",
            "connected to every account"
        ]
        for phrase in forbidden {
            #expect(!label.contains(phrase), "Forbidden copy in display label: \(phrase)")
        }
        #expect(label.contains("plaid_sandbox"))
    }

    @Test("logKey round-trips through FinancialDataProviderKind.fromLogKey")
    func logKeyRoundTrip() {
        let kind = FinancialDataProviderKind.externalAggregator(identifier: "plaid_sandbox")
        let key = kind.logKey
        #expect(key == "external_aggregator.plaid_sandbox")
        #expect(FinancialDataProviderKind.fromLogKey(key) == kind)
    }
}

// MARK: - In-memory storage

private final class InMemoryStorage: PlaidSandboxConfigurationStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [KeychainService.Key: String] = [:]

    func loadString(_ key: KeychainService.Key) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }
    func save(_ value: String, _ key: KeychainService.Key) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }
    func delete(_ key: KeychainService.Key) {
        lock.lock()
        defer { lock.unlock() }
        _ = values.removeValue(forKey: key)
    }
}
