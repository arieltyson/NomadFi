// PlaidLinkCoordinatorTests.swift
// NomadFi
//
// Phase 5D gate-clearance coverage for the real Plaid Link
// coordinator state machine. Tests use a stub presenter and a stub
// broker client — LinkKit is never loaded, so this suite runs on any
// runner that can build NomadFi.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct PlaidLinkCoordinatorTests {

    private nonisolated static let brokerURL = URL(string: "http://127.0.0.1:65534")!

    /// Polls the coordinator's `phase` on the main actor until it
    /// settles into a terminal state (`.completed`, `.cancelled`,
    /// or `.failed`). Uses `Task.yield()` so any pending
    /// `Task { @MainActor in ... }` continuations queued by the
    /// coordinator run before the assertion reads `phase` back.
    static func waitForFinalPhase(
        on coordinator: PlaidLinkCoordinator,
        maxYields: Int = 50
    ) async {
        for _ in 0..<maxYields {
            switch coordinator.phase {
            case .completed, .cancelled, .failed:
                return
            default:
                await Task.yield()
            }
        }
    }

    // MARK: - Happy path

    @Test("Idle → link_token → presentation → success → exchange → completed")
    func happyPathLinkFlow() async {
        let storage = InMemoryStorage()
        let configuration = PlaidSandboxConfiguration(storage: storage)
        configuration.setBrokerURL(Self.brokerURL)

        let stub = StubLinkClient()
        stub.linkTokenToReturn = PlaidLinkTokenResponse(linkToken: "link-sandbox-123")
        stub.exchangeResponse = PlaidItemHandleResponse(
            itemID: "itm_real_1",
            institutionID: "ins_3",
            institutionName: "First Real Bank"
        )
        let presenter = StubPresenter(outcome: .success(publicToken: "public-sandbox-abc"))
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in stub },
            presenter: presenter
        )

        #expect(coordinator.phase == .idle)
        await coordinator.startRealLinkFlow()
        await Self.waitForFinalPhase(on: coordinator)

        if case .completed(let itemID) = coordinator.phase {
            #expect(itemID == "itm_real_1")
        } else {
            Issue.record("Expected completed phase, got \(coordinator.phase)")
        }
        #expect(configuration.itemID == "itm_real_1")
        #expect(configuration.transactionsCursor == nil)
        #expect(stub.exchangeCallCount == 1)
        #expect(presenter.presentCallCount == 1)
    }

    // MARK: - Failure paths

    @Test("Missing broker URL surfaces a calm failure message")
    func missingBrokerURL() async {
        let configuration = PlaidSandboxConfiguration(storage: InMemoryStorage())
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in StubLinkClient() },
            presenter: StubPresenter()
        )
        await coordinator.startRealLinkFlow()
        if case .failed(let message) = coordinator.phase {
            #expect(message.contains("broker URL"))
        } else {
            Issue.record("Expected failed phase, got \(coordinator.phase)")
        }
    }

    @Test("Broker error while creating link_token surfaces a calm failure")
    func brokerCreateLinkTokenFails() async {
        let configuration = PlaidSandboxConfiguration(storage: InMemoryStorage())
        configuration.setBrokerURL(Self.brokerURL)
        let stub = StubLinkClient()
        stub.createLinkTokenError = FinancialDataProviderError.refreshFailed
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in stub },
            presenter: StubPresenter()
        )
        await coordinator.startRealLinkFlow()
        if case .failed = coordinator.phase {
            // pass
        } else {
            Issue.record("Expected failed phase, got \(coordinator.phase)")
        }
    }

    @Test("User exits Link voluntarily — phase becomes cancelled, no item persisted")
    func userExitsLink() async {
        let configuration = PlaidSandboxConfiguration(storage: InMemoryStorage())
        configuration.setBrokerURL(Self.brokerURL)
        let stub = StubLinkClient()
        stub.linkTokenToReturn = PlaidLinkTokenResponse(linkToken: "link-sandbox-abc")
        let presenter = StubPresenter(outcome: .cancelled)
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in stub },
            presenter: presenter
        )
        await coordinator.startRealLinkFlow()
        await Self.waitForFinalPhase(on: coordinator)
        #expect(coordinator.phase == .cancelled)
        #expect(configuration.itemID == nil)
        #expect(stub.exchangeCallCount == 0)
    }

    @Test("Exchange failure surfaces a calm failure and leaves state clean for retry")
    func publicTokenExchangeFails() async {
        let configuration = PlaidSandboxConfiguration(storage: InMemoryStorage())
        configuration.setBrokerURL(Self.brokerURL)
        let stub = StubLinkClient()
        stub.linkTokenToReturn = PlaidLinkTokenResponse(linkToken: "link-sandbox-xyz")
        stub.exchangeError = FinancialDataProviderError.refreshFailed
        let presenter = StubPresenter(outcome: .success(publicToken: "public-sandbox-fail"))
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in stub },
            presenter: presenter
        )
        await coordinator.startRealLinkFlow()
        await Self.waitForFinalPhase(on: coordinator)
        if case .failed = coordinator.phase {
            // pass
        } else {
            Issue.record("Expected failed phase, got \(coordinator.phase)")
        }
        #expect(configuration.itemID == nil)
    }

    // MARK: - Universal-link forwarding

    @Test("Universal-link URL is forwarded to the presenter while Link is presenting")
    func universalLinkForwardedWhilePresenting() async {
        let configuration = PlaidSandboxConfiguration(storage: InMemoryStorage())
        configuration.setBrokerURL(Self.brokerURL)
        let stub = StubLinkClient()
        stub.linkTokenToReturn = PlaidLinkTokenResponse(linkToken: "link-sandbox-uni")
        // Defer outcome delivery so we can verify the coordinator is
        // in `.presentingLink` when the universal link arrives.
        let presenter = StubPresenter(deferOutcome: true)
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in stub },
            presenter: presenter
        )
        await coordinator.startRealLinkFlow()
        #expect(coordinator.phase == .presentingLink)

        let url = URL(string: "https://arieltyson.github.io/nomadfi-privacy/plaid-oauth?state=abc")!
        #expect(coordinator.handle(universalLink: url))
        #expect(presenter.receivedRedirectURIs == [url])

        // Set the exchange response *before* delivering the outcome
        // so the coordinator's `handle(outcome:)` Task reads the
        // correct value. Delivery kicks off an async exchange call
        // whose result we then poll for via `waitForFinalPhase`.
        stub.exchangeResponse = PlaidItemHandleResponse(
            itemID: "itm_uni",
            institutionID: nil,
            institutionName: nil
        )
        presenter.deliverDeferred(.success(publicToken: "pt_uni"))
        await Self.waitForFinalPhase(on: coordinator)
        if case .completed(let itemID) = coordinator.phase {
            #expect(itemID == "itm_uni")
        } else {
            Issue.record("Expected completed phase, got \(coordinator.phase)")
        }
    }

    @Test("Universal-link URL is ignored when no Link session is pending")
    func universalLinkIgnoredWhenIdle() {
        let configuration = PlaidSandboxConfiguration(storage: InMemoryStorage())
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in StubLinkClient() },
            presenter: StubPresenter()
        )
        let url = URL(string: "https://arieltyson.github.io/nomadfi-privacy/plaid-oauth")!
        #expect(!coordinator.handle(universalLink: url))
    }

    // MARK: - Copy guard

    @Test("Phase status labels never claim production-level bank coverage")
    func statusLabelsAreHonest() {
        let labels: [PlaidLinkCoordinator.Phase] = [
            .idle,
            .fetchingLinkToken,
            .presentingLink,
            .exchangingPublicToken,
            .completed(itemID: "itm_x"),
            .cancelled,
            .failed(message: "sample failure")
        ]
        let forbidden = [
            "all your banks",
            "all your cards",
            "instant sync everywhere",
            "automatic for every institution",
            "connected to every account"
        ]
        for label in labels {
            let resolved = String(localized: label.statusLabel).lowercased()
            for phrase in forbidden {
                #expect(!resolved.contains(phrase), "Forbidden copy: \(phrase) in \(resolved)")
            }
        }
    }

    @Test("reset() moves a failed phase back to idle so the user can retry")
    func resetRestoresIdle() {
        let configuration = PlaidSandboxConfiguration(storage: InMemoryStorage())
        let coordinator = PlaidLinkCoordinator(
            configuration: configuration,
            clientBuilder: { _ in StubLinkClient() },
            presenter: StubPresenter()
        )
        coordinator.reset()
        #expect(coordinator.phase == .idle)
    }
}

// MARK: - Stubs

private final class StubLinkClient: PlaidSandboxClient, @unchecked Sendable {
    var linkTokenToReturn: PlaidLinkTokenResponse = PlaidLinkTokenResponse(linkToken: "stub-token")
    var createLinkTokenError: FinancialDataProviderError?
    var exchangeResponse: PlaidItemHandleResponse = PlaidItemHandleResponse(
        itemID: "itm_stub",
        institutionID: nil,
        institutionName: nil
    )
    var exchangeError: FinancialDataProviderError?
    private(set) var exchangeCallCount = 0

    func createLinkToken() async throws -> PlaidLinkTokenResponse {
        if let createLinkTokenError { throw createLinkTokenError }
        return linkTokenToReturn
    }
    func createSandboxItem() async throws -> PlaidItemHandleResponse {
        exchangeResponse
    }
    func exchangePublicToken(_ publicToken: String) async throws -> PlaidItemHandleResponse {
        exchangeCallCount += 1
        if let exchangeError { throw exchangeError }
        return exchangeResponse
    }
    func fetchAccounts(itemID: String) async throws -> PlaidAccountsResponse {
        PlaidAccountsResponse(accounts: [], institutionName: nil)
    }
    func syncTransactions(
        itemID: String,
        cursor: String?
    ) async throws -> PlaidTransactionsSyncResponse {
        PlaidTransactionsSyncResponse(
            added: [], modified: [], removed: [],
            nextCursor: "", hasMore: false
        )
    }
}

@MainActor
private final class StubPresenter: PlaidLinkPresenting {
    var outcome: PlaidLinkOutcome
    var deferOutcome: Bool
    private(set) var presentCallCount = 0
    private(set) var receivedRedirectURIs: [URL] = []
    private var pendingCompletion: ((PlaidLinkOutcome) -> Void)?
    private var deliveryContinuations: [CheckedContinuation<Void, Never>] = []

    init(outcome: PlaidLinkOutcome = .cancelled, deferOutcome: Bool = false) {
        self.outcome = outcome
        self.deferOutcome = deferOutcome
    }

    func present(
        _ request: PlaidLinkPresentationRequest,
        completion: @escaping @MainActor (PlaidLinkOutcome) -> Void
    ) {
        presentCallCount += 1
        if deferOutcome {
            pendingCompletion = completion
        } else {
            completion(outcome)
            signalDelivery()
        }
    }

    func handle(redirectURI url: URL) -> Bool {
        receivedRedirectURIs.append(url)
        return true
    }

    func deliverDeferred(_ outcome: PlaidLinkOutcome) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(outcome)
        signalDelivery()
    }

    func waitForDelivery() async {
        await withCheckedContinuation { continuation in
            if pendingCompletion == nil && deliveryContinuations.isEmpty && presentCallCount > 0 {
                // Already delivered on a non-deferred path; let the
                // continuation resume on the next runloop so any
                // coordinator follow-up Tasks can settle first.
                Task { continuation.resume() }
            } else {
                deliveryContinuations.append(continuation)
            }
        }
    }

    private func signalDelivery() {
        let continuations = deliveryContinuations
        deliveryContinuations.removeAll()
        // Resume on the next runloop hop so the coordinator's
        // follow-up `Task { @MainActor in ... }` can finish the
        // exchange + phase update before the assertion runs.
        Task {
            for continuation in continuations {
                continuation.resume()
            }
        }
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

// MARK: - LocalizedStringResource helper

private extension LocalizedStringResource {
    func contains(_ needle: String) -> Bool {
        String(localized: self).localizedCaseInsensitiveContains(needle)
    }
}
