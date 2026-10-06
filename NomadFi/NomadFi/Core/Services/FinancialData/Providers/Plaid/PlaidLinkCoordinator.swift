// PlaidLinkCoordinator.swift
// NomadFi
//
// Drives one real Plaid Link session from end-to-end:
//
//   1. Ask the broker for a `link_token` (OAuth redirect URI applied
//      broker-side when the environment has it configured).
//   2. Hand the token to the ``PlaidLinkPresenting`` seam, which
//      opens LinkKit's UI.
//   3. Capture the `public_token` from Link's `onSuccess` callback.
//   4. Exchange the `public_token` through the broker for the
//      opaque item handle NomadFi persists in the Keychain.
//   5. Clear cursor state so the first `/transactions/sync` pulls
//      the initial transaction diff.
//
// Universal-link returns from OAuth-capable institutions flow back
// through ``handle(universalLink:)``; the coordinator forwards the
// URL to the presenter for LinkKit's `handler.continue(from:)`.
//
// The coordinator is `@MainActor` and `@Observable` so Settings UI
// can bind to `phase` directly.

import Foundation
import OSLog

/// Finite state machine the Settings row drives. Transitions are
/// deterministic so tests can assert against them without touching
/// LinkKit.
@MainActor
@Observable
final class PlaidLinkCoordinator {

    enum Phase: Sendable, Equatable {
        case idle
        case fetchingLinkToken
        case presentingLink
        case exchangingPublicToken
        case completed(itemID: String)
        case cancelled
        case failed(message: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var linkedInstitutionName: String?

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.PlaidSandbox.LinkCoordinator"
    )

    private let configuration: PlaidSandboxConfiguration
    private let clientBuilder: @Sendable (URL) -> any PlaidSandboxClient
    private let presenter: any PlaidLinkPresenting

    /// Initializer. Defaults wire to the Keychain-backed configuration
    /// and the URLSession-based broker client.
    init(
        configuration: PlaidSandboxConfiguration = PlaidSandboxConfiguration(),
        clientBuilder: (@Sendable (URL) -> any PlaidSandboxClient)? = nil,
        presenter: any PlaidLinkPresenting = PlaidLinkKitPresenter()
    ) {
        self.configuration = configuration
        let capturedConfiguration = configuration
        self.clientBuilder = clientBuilder ?? { url in
            LivePlaidSandboxClient(
                baseURL: url,
                brokerSecret: capturedConfiguration.brokerSecret
            )
        }
        self.presenter = presenter
    }

    // MARK: - Public API

    /// Launches a real Plaid Link session. No-op if the configuration
    /// has no broker URL (the Settings row handles that case with a
    /// calm "configure broker first" label).
    func startRealLinkFlow() async {
        guard case .idle = phase else { return }
        guard let brokerURL = configuration.brokerURL else {
            phase = .failed(message: "Plaid sandbox broker URL is not configured.")
            return
        }

        phase = .fetchingLinkToken
        let client = clientBuilder(brokerURL)
        let linkToken: String
        do {
            linkToken = try await client.createLinkToken().linkToken
        } catch {
            Self.logger.error(
                "Plaid link_token creation failed: \(error.localizedDescription, privacy: .public)"
            )
            phase = .failed(message: "Could not create a Plaid link token. Check the broker is running.")
            return
        }

        phase = .presentingLink
        let request = PlaidLinkPresentationRequest(
            linkToken: linkToken,
            receivedRedirectURI: nil
        )
        presenter.present(request) { [weak self] outcome in
            guard let self else { return }
            Task { @MainActor in
                await self.handle(outcome: outcome, brokerURL: brokerURL)
            }
        }
    }

    /// Forwards a universal-link URL from the app's scene handler
    /// into the pending Link session. Returns `true` when the URL
    /// was consumed; callers can branch on `false` to display a
    /// calm fallback.
    @discardableResult
    func handle(universalLink url: URL) -> Bool {
        guard case .presentingLink = phase else { return false }
        return presenter.handle(redirectURI: url)
    }

    /// Allows the Settings UI to reset after a failure so the user
    /// can retry without restarting the app.
    func reset() {
        linkedInstitutionName = nil
        phase = .idle
    }

    // MARK: - Private

    private func handle(outcome: PlaidLinkOutcome, brokerURL: URL) async {
        switch outcome {
        case .cancelled:
            phase = .cancelled
        case .failed(let message):
            phase = .failed(message: message)
        case .success(let publicToken):
            phase = .exchangingPublicToken
            let client = clientBuilder(brokerURL)
            do {
                let handle = try await client.exchangePublicToken(publicToken)
                configuration.setItemID(handle.itemID)
                // Reset any pre-existing cursor so the first
                // `/transactions/sync` gets the full initial diff
                // for the new item.
                configuration.setTransactionsCursor(nil)
                linkedInstitutionName = handle.institutionName
                phase = .completed(itemID: handle.itemID)
            } catch {
                Self.logger.error(
                    "Plaid public_token exchange failed: \(error.localizedDescription, privacy: .public)"
                )
                phase = .failed(message: "Could not exchange the Plaid public token.")
            }
        }
    }
}

// MARK: - Localised labels

extension PlaidLinkCoordinator.Phase {

    /// Calm, factual label the Settings row renders. Never claims
    /// production-level "connect all your banks" coverage.
    var statusLabel: LocalizedStringResource {
        switch self {
        case .idle: return "Ready to link a sandbox bank"
        case .fetchingLinkToken: return "Contacting Plaid sandbox broker…"
        case .presentingLink: return "Showing Plaid Link"
        case .exchangingPublicToken: return "Finishing the link"
        case .completed: return "Sandbox bank linked"
        case .cancelled: return "Link cancelled"
        case .failed(let message): return "Link failed: \(message)"
        }
    }

    /// True while the coordinator is mid-session. The Settings row
    /// hides the "Link a sandbox bank" button during this window so
    /// a second tap can't fire a second session.
    var isBusy: Bool {
        switch self {
        case .fetchingLinkToken, .presentingLink, .exchangingPublicToken:
            return true
        default:
            return false
        }
    }
}
