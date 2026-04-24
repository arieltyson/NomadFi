// PlaidSandboxDeveloperConfigViewModel.swift
// NomadFi
//
// Backs the developer-only Plaid sandbox diagnostics page under
// Settings → Financial Setup → Financial Connections. Never visible
// in production (the enclosing view is gated by `#if DEBUG`).
//
// Responsibilities:
//
// 1. Read / write the three Plaid sandbox Keychain values without
//    relying on Xcode breakpoints or a debug-helper REPL.
// 2. Validate broker URLs before persisting them.
// 3. Run a narrow `GET /health` probe against the broker so a
//    developer can tell, from the device, whether the broker is
//    reachable, whether it expects a shared secret, and whether
//    `PLAID_REDIRECT_URI` is configured on the broker side.
// 4. Offer explicit clear actions — "Clear linked item" and
//    "Reset all" — so a developer can retry a failed Link attempt
//    without uninstalling the app.
//
// All copy routed through this VM is factual. It never implies
// production coverage; every label surfaces that this path is a
// developer-only validation harness.

import Foundation
import OSLog

@MainActor
@Observable
final class PlaidSandboxDeveloperConfigViewModel {

    // MARK: - Fields

    /// Raw text the developer types into the broker-URL field.
    /// Separate from `configuration.brokerURL` so we can validate
    /// before persisting.
    var brokerURLText: String

    /// Raw text for the optional shared secret. Stays local to the
    /// VM until saved.
    var brokerSecretText: String

    /// Result of the last "Save" action. Resets on the next edit.
    private(set) var lastSaveOutcome: SaveOutcome?

    /// Result of the last health probe.
    private(set) var healthStatus: HealthStatus = .unknown

    /// Whether a health check is currently in flight.
    private(set) var isHealthChecking: Bool = false

    // MARK: - Dependencies

    private let configuration: PlaidSandboxConfiguration
    private let clientBuilder: @Sendable (URL, String?) -> any PlaidSandboxClient

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.PlaidSandbox.DeveloperConfig"
    )

    init(
        configuration: PlaidSandboxConfiguration = PlaidSandboxConfiguration(),
        clientBuilder: (@Sendable (URL, String?) -> any PlaidSandboxClient)? = nil
    ) {
        self.configuration = configuration
        self.clientBuilder = clientBuilder ?? { url, secret in
            LivePlaidSandboxClient(baseURL: url, brokerSecret: secret)
        }
        self.brokerURLText = configuration.brokerURL?.absoluteString ?? ""
        self.brokerSecretText = configuration.brokerSecret ?? ""
    }

    // MARK: - Derived state

    /// Human-readable summary of the current linked-item state. The
    /// view uses this to show a calm line under the save button.
    var linkedItemSummary: LinkedItemSummary {
        if let itemID = configuration.itemID {
            return .linked(itemID: itemID)
        }
        if configuration.brokerURL != nil {
            return .readyToLink
        }
        return .unconfigured
    }

    /// Whether the "Save" button should be enabled. Empty URL text
    /// means clear, so that's always allowed.
    var canSave: Bool {
        let trimmed = brokerURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return PlaidSandboxConfiguration.normalize(brokerURLCandidate: trimmed) != nil
    }

    // MARK: - Actions

    /// Normalises and persists the broker URL + secret. Clears the
    /// broker URL when the field is empty. Resets `healthStatus`
    /// because the next probe runs against a potentially different
    /// broker. When a validation recorder is attached, every save
    /// path records a redaction-safe event.
    func save(recorder: PlaidValidationRecorder? = nil) {
        lastSaveOutcome = nil
        let trimmedURL = brokerURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            configuration.setBrokerURL(nil)
            configuration.setBrokerSecret(nil)
            brokerSecretText = ""
            healthStatus = .unknown
            lastSaveOutcome = .cleared
            recorder?.recordBrokerConfigCleared()
            return
        }
        guard let normalized = PlaidSandboxConfiguration.normalize(
            brokerURLCandidate: trimmedURL
        ) else {
            lastSaveOutcome = .invalidURL
            return
        }
        configuration.setBrokerURL(normalized)
        brokerURLText = normalized.absoluteString
        let trimmedSecret = brokerSecretText.trimmingCharacters(in: .whitespacesAndNewlines)
        configuration.setBrokerSecret(trimmedSecret.isEmpty ? nil : trimmedSecret)
        healthStatus = .unknown
        lastSaveOutcome = .saved
        recorder?.recordBrokerConfigSaved(
            brokerURL: normalized,
            hasSecret: !trimmedSecret.isEmpty
        )
    }

    /// Runs `GET /health` against the currently-saved broker URL +
    /// secret. Uses whatever is *persisted*, not the text field, so
    /// the developer must hit Save first. This keeps the probe
    /// deterministic.
    func runHealthCheck(recorder: PlaidValidationRecorder? = nil) async {
        guard !isHealthChecking else { return }
        isHealthChecking = true
        defer { isHealthChecking = false }

        guard let url = configuration.brokerURL else {
            healthStatus = .missingConfiguration
            return
        }
        let client = clientBuilder(url, configuration.brokerSecret)
        do {
            let response = try await client.health()
            healthStatus = .reachable(
                env: response.env,
                requiresSecret: response.requiresSecret ?? false,
                redirectURIConfigured: response.redirectURIConfigured ?? false
            )
            recorder?.recordBrokerHealthChecked(
                reachable: true,
                env: response.env,
                requiresSecret: response.requiresSecret,
                redirectConfigured: response.redirectURIConfigured
            )
        } catch let error as FinancialDataProviderError {
            Self.logger.info(
                "Plaid broker health probe failed (\(String(describing: error), privacy: .public))"
            )
            healthStatus = .unreachable
            recorder?.recordBrokerHealthChecked(
                reachable: false,
                failureReason: String(describing: error)
            )
        } catch {
            Self.logger.info(
                "Plaid broker health probe failed: \(error.localizedDescription, privacy: .public)"
            )
            healthStatus = .unreachable
            recorder?.recordBrokerHealthChecked(
                reachable: false,
                failureReason: error.localizedDescription
            )
        }
    }

    /// Clears the Plaid item handle + `/transactions/sync` cursor
    /// so a developer can retry a failed Link attempt without
    /// losing broker config or rebuilding the sandbox.
    func clearLinkedItem(recorder: PlaidValidationRecorder? = nil) {
        configuration.clearLinkedItem()
        recorder?.recordItemHandleCleared()
    }

    /// Clears every Plaid sandbox Keychain value owned by the
    /// configuration. Mirrors the "Reset all" button.
    func resetAll() {
        configuration.clearAll()
        brokerURLText = ""
        brokerSecretText = ""
        healthStatus = .unknown
        lastSaveOutcome = .cleared
    }

    // MARK: - Nested types

    /// Outcome of the last save attempt. The view renders the status
    /// line under the Save button from this value.
    enum SaveOutcome: Sendable, Equatable {
        case saved
        case invalidURL
        case cleared

        var label: LocalizedStringResource {
            switch self {
            case .saved: return "Broker URL saved."
            case .invalidURL: return "Not a valid broker URL. Use http or https with a host."
            case .cleared: return "Cleared."
            }
        }
    }

    /// Health-check outcome, translated into a calm status string.
    enum HealthStatus: Sendable, Equatable {
        case unknown
        case missingConfiguration
        case reachable(env: String, requiresSecret: Bool, redirectURIConfigured: Bool)
        case unreachable

        var label: LocalizedStringResource {
            switch self {
            case .unknown:
                return "Broker health not yet checked."
            case .missingConfiguration:
                return "Broker URL not set. Save one first, then run health check."
            case .reachable(let env, let requiresSecret, let redirectURIConfigured):
                let secret = requiresSecret ? "secret required" : "no secret"
                let redirect = redirectURIConfigured ? "redirect configured" : "redirect not configured"
                return "Broker reachable (env=\(env), \(secret), \(redirect))."
            case .unreachable:
                return "Broker not reachable from this device."
            }
        }

        var iconName: String {
            switch self {
            case .unknown, .missingConfiguration: return "questionmark.circle"
            case .reachable: return "checkmark.circle"
            case .unreachable: return "xmark.circle"
            }
        }
    }

    /// Summary of whether a Plaid item has been linked via this
    /// configuration. The view displays one line per state.
    enum LinkedItemSummary: Sendable, Equatable {
        case unconfigured
        case readyToLink
        case linked(itemID: String)

        var label: LocalizedStringResource {
            switch self {
            case .unconfigured:
                return "No broker URL configured. Plaid sandbox is inactive."
            case .readyToLink:
                return "Broker URL configured. No Plaid item linked yet."
            case .linked(let itemID):
                return "Plaid item linked (handle \(itemID))."
            }
        }
    }
}
