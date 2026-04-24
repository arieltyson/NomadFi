// PlaidSandboxDeveloperConfigTests.swift
// NomadFi
//
// Phase 5D operational-unblock coverage for the DEBUG-only Plaid
// sandbox developer harness. Every test runs against an in-memory
// storage stub so nothing touches the real Keychain, and against a
// stub broker client so nothing reaches the network.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct PlaidSandboxDeveloperConfigTests {

    // MARK: - URL validation

    @Test("Normalizer accepts well-formed http / https URLs and strips fragments")
    func urlValidationAcceptsGoodURLs() {
        let http = PlaidSandboxConfiguration.normalize(
            brokerURLCandidate: " http://192.168.1.42:8787 "
        )
        #expect(http?.absoluteString == "http://192.168.1.42:8787")

        let https = PlaidSandboxConfiguration.normalize(
            brokerURLCandidate: "https://dev.local:9000/#fragment"
        )
        #expect(https?.absoluteString == "https://dev.local:9000/")

        let path = PlaidSandboxConfiguration.normalize(
            brokerURLCandidate: "http://127.0.0.1:8787/api"
        )
        #expect(path?.absoluteString == "http://127.0.0.1:8787/api")
    }

    @Test("Normalizer rejects empty, non-http(s), no-host, and user-info URLs")
    func urlValidationRejectsBadURLs() {
        #expect(PlaidSandboxConfiguration.normalize(brokerURLCandidate: "") == nil)
        #expect(PlaidSandboxConfiguration.normalize(brokerURLCandidate: "   ") == nil)
        #expect(PlaidSandboxConfiguration.normalize(brokerURLCandidate: "ftp://example.com") == nil)
        #expect(PlaidSandboxConfiguration.normalize(brokerURLCandidate: "not a url") == nil)
        #expect(
            PlaidSandboxConfiguration.normalize(
                brokerURLCandidate: "http://user:pass@example.com"
            ) == nil
        )
    }

    // MARK: - Configuration round-trip (including the new secret + clear helpers)

    @Test("clearLinkedItem wipes item + cursor but preserves broker URL + secret")
    func clearLinkedItemPreservesBrokerConfig() {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setBrokerURL(URL(string: "http://127.0.0.1:8787")!)
        config.setBrokerSecret("sekret123456789012")
        config.setItemID("itm_keepme_first")
        config.setTransactionsCursor("cursor-1")

        config.clearLinkedItem()

        #expect(config.brokerURL?.absoluteString == "http://127.0.0.1:8787")
        #expect(config.brokerSecret == "sekret123456789012")
        #expect(config.itemID == nil)
        #expect(config.transactionsCursor == nil)
    }

    @Test("clearAll wipes every Plaid sandbox Keychain value")
    func clearAllWipesEverything() {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setBrokerURL(URL(string: "http://192.168.1.42:8787")!)
        config.setBrokerSecret("another-secret")
        config.setItemID("itm_delete")
        config.setTransactionsCursor("cursor-2")

        config.clearAll()

        #expect(config.brokerURL == nil)
        #expect(config.brokerSecret == nil)
        #expect(config.itemID == nil)
        #expect(config.transactionsCursor == nil)
    }

    // MARK: - Developer config VM

    @Test("VM canSave is true for empty text (clear) and valid URLs, false for bad ones")
    func canSaveHonoursValidation() {
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: PlaidSandboxConfiguration(storage: InMemoryStorage()),
            clientBuilder: { _, _ in StubHealthClient() }
        )
        vm.brokerURLText = ""
        #expect(vm.canSave)

        vm.brokerURLText = "http://192.168.1.42:8787"
        #expect(vm.canSave)

        vm.brokerURLText = "not a url"
        #expect(!vm.canSave)
    }

    @Test("Save persists a valid URL + secret and sets lastSaveOutcome to .saved")
    func savePersistsValidURL() {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in StubHealthClient() }
        )
        vm.brokerURLText = "http://192.168.1.42:8787"
        vm.brokerSecretText = "abcd1234abcd1234"
        vm.save()
        #expect(vm.lastSaveOutcome == .saved)
        #expect(config.brokerURL?.absoluteString == "http://192.168.1.42:8787")
        #expect(config.brokerSecret == "abcd1234abcd1234")
    }

    @Test("Save with empty URL clears the broker config and marks the outcome as cleared")
    func saveEmptyClearsConfiguration() {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        config.setBrokerURL(URL(string: "http://192.168.1.42:8787")!)
        config.setBrokerSecret("will-be-cleared")
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in StubHealthClient() }
        )
        vm.brokerURLText = "  "
        vm.save()
        #expect(vm.lastSaveOutcome == .cleared)
        #expect(config.brokerURL == nil)
        #expect(config.brokerSecret == nil)
    }

    @Test("Save with an invalid URL does not persist and reports invalidURL")
    func saveInvalidURL() {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in StubHealthClient() }
        )
        vm.brokerURLText = "not a url at all"
        vm.save()
        #expect(vm.lastSaveOutcome == .invalidURL)
        #expect(config.brokerURL == nil)
    }

    @Test("Health check maps a successful response onto the reachable state")
    func healthCheckReachable() async {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        config.setBrokerURL(URL(string: "http://127.0.0.1:8787")!)
        let stub = StubHealthClient()
        stub.response = PlaidBrokerHealthResponse(
            ok: true,
            env: "sandbox",
            requiresSecret: true,
            redirectURIConfigured: true
        )
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in stub }
        )
        await vm.runHealthCheck()
        if case .reachable(let env, let requiresSecret, let redirectConfigured) = vm.healthStatus {
            #expect(env == "sandbox")
            #expect(requiresSecret)
            #expect(redirectConfigured)
        } else {
            Issue.record("Expected .reachable, got \(vm.healthStatus)")
        }
    }

    @Test("Health check without a broker URL yields missingConfiguration, not unreachable")
    func healthCheckMissingConfig() async {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in StubHealthClient() }
        )
        await vm.runHealthCheck()
        #expect(vm.healthStatus == .missingConfiguration)
    }

    @Test("Health check that throws maps to unreachable (never silently reachable)")
    func healthCheckUnreachable() async {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        config.setBrokerURL(URL(string: "http://127.0.0.1:8787")!)
        let stub = StubHealthClient()
        stub.errorToThrow = .refreshFailed
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in stub }
        )
        await vm.runHealthCheck()
        #expect(vm.healthStatus == .unreachable)
    }

    // MARK: - Linked-item summary

    @Test("Linked-item summary transitions through unconfigured → readyToLink → linked")
    func linkedItemSummaryTransitions() {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in StubHealthClient() }
        )
        #expect(vm.linkedItemSummary == .unconfigured)

        config.setBrokerURL(URL(string: "http://127.0.0.1:8787")!)
        #expect(vm.linkedItemSummary == .readyToLink)

        config.setItemID("itm_here")
        #expect(vm.linkedItemSummary == .linked(itemID: "itm_here"))
    }

    @Test("resetAll clears text fields, config, and health status")
    func resetAllClearsEverything() {
        let config = PlaidSandboxConfiguration(storage: InMemoryStorage())
        config.setBrokerURL(URL(string: "http://192.168.1.42:8787")!)
        config.setBrokerSecret("existing")
        config.setItemID("itm_old")
        let vm = PlaidSandboxDeveloperConfigViewModel(
            configuration: config,
            clientBuilder: { _, _ in StubHealthClient() }
        )
        vm.resetAll()
        #expect(vm.brokerURLText == "")
        #expect(vm.brokerSecretText == "")
        #expect(vm.healthStatus == .unknown)
        #expect(config.brokerURL == nil)
        #expect(config.itemID == nil)
        #expect(config.brokerSecret == nil)
    }

    // MARK: - Copy guard

    @Test("Developer-harness copy never claims production coverage")
    func copyGuardForDeveloperHarness() {
        let statuses: [PlaidSandboxDeveloperConfigViewModel.HealthStatus] = [
            .unknown,
            .missingConfiguration,
            .reachable(env: "sandbox", requiresSecret: false, redirectURIConfigured: false),
            .reachable(env: "sandbox", requiresSecret: true, redirectURIConfigured: true),
            .unreachable
        ]
        let outcomes: [PlaidSandboxDeveloperConfigViewModel.SaveOutcome] = [
            .saved, .invalidURL, .cleared
        ]
        let summaries: [PlaidSandboxDeveloperConfigViewModel.LinkedItemSummary] = [
            .unconfigured, .readyToLink, .linked(itemID: "itm_x")
        ]
        let forbidden = [
            "all your banks",
            "all your cards",
            "instant sync everywhere",
            "automatic for every institution",
            "connected to every account",
            "production rollout"
        ]
        for raw in statuses.map({ $0.label }) + outcomes.map({ $0.label }) + summaries.map({ $0.label }) {
            let text = String(localized: raw).lowercased()
            for phrase in forbidden {
                #expect(
                    !text.contains(phrase),
                    "Forbidden copy in developer harness label: \(phrase) → \(text)"
                )
            }
        }
    }
}

// MARK: - Stubs

@MainActor
private final class StubHealthClient: PlaidSandboxClient {
    var response: PlaidBrokerHealthResponse = PlaidBrokerHealthResponse(
        ok: true,
        env: "sandbox",
        requiresSecret: false,
        redirectURIConfigured: false
    )
    var errorToThrow: FinancialDataProviderError?

    func health() async throws -> PlaidBrokerHealthResponse {
        if let errorToThrow { throw errorToThrow }
        return response
    }
    func createLinkToken() async throws -> PlaidLinkTokenResponse {
        PlaidLinkTokenResponse(linkToken: "stub-token")
    }
    func createSandboxItem() async throws -> PlaidItemHandleResponse {
        PlaidItemHandleResponse(itemID: "itm_stub", institutionID: nil, institutionName: nil)
    }
    func exchangePublicToken(_ publicToken: String) async throws -> PlaidItemHandleResponse {
        PlaidItemHandleResponse(itemID: "itm_stub", institutionID: nil, institutionName: nil)
    }
    func fetchAccounts(itemID: String) async throws -> PlaidAccountsResponse {
        PlaidAccountsResponse(accounts: [], institutionName: nil)
    }
    func syncTransactions(
        itemID: String,
        cursor: String?
    ) async throws -> PlaidTransactionsSyncResponse {
        PlaidTransactionsSyncResponse(
            added: [], modified: [], removed: [], nextCursor: "", hasMore: false
        )
    }
}

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
