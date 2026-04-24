// PlaidSandboxConfiguration.swift
// NomadFi
//
// Reads and writes the three Plaid sandbox configuration values the
// app is allowed to know:
//
// 1. The broker's base URL (e.g. `http://127.0.0.1:8787`).
// 2. The opaque item handle the broker returns after it has exchanged
//    Plaid's `public_token` for an `access_token`.
// 3. The `/transactions/sync` cursor for incremental pulls.
//
// The app never sees, stores, or transmits Plaid `client_id` or
// `secret`. Those live only inside `tools/plaid-sandbox-broker/.env`,
// which is git-ignored by design.
//
// Storage backing is `KeychainService` — same device-only, not-
// iCloud-synced, not-in-backups accessibility NomadFi already uses
// for the biometric app-lock state.

import Foundation

/// Narrow, value-typed façade over the Keychain keys owned by the
/// Plaid sandbox proof. Exists to keep call sites tidy and to pin the
/// "never embed Plaid secrets" invariant in one place.
struct PlaidSandboxConfiguration: Sendable {

    private let storage: any PlaidSandboxConfigurationStorage

    init(storage: any PlaidSandboxConfigurationStorage = KeychainPlaidSandboxConfigurationStorage()) {
        self.storage = storage
    }

    // MARK: - Reads

    /// Base URL the app should hit for the broker. `nil` means the
    /// sandbox provider stays in the `integrationNotImplemented` state
    /// — the Settings row reads "Not enabled in this build".
    var brokerURL: URL? {
        guard let raw = storage.loadString(.plaidSandboxBrokerURL),
              !raw.isEmpty,
              let url = URL(string: raw)
        else { return nil }
        return url
    }

    /// Opaque handle from the broker. Absent means no Plaid item is
    /// linked yet; the provider reports `.availableNoConnections` or
    /// `.authorizationRequired` accordingly.
    var itemID: String? {
        storage.loadString(.plaidSandboxItemID)
    }

    /// Persisted `/transactions/sync` cursor. Absent on first sync.
    var transactionsCursor: String? {
        storage.loadString(.plaidSandboxTransactionsCursor)
    }

    /// Shared secret the client sends as
    /// `X-NomadFi-Broker-Secret` when the developer has started the
    /// broker in LAN mode. Optional: loopback-mode brokers don't
    /// require one.
    var brokerSecret: String? {
        storage.loadString(.plaidSandboxBrokerSecret)
    }

    // MARK: - Writes

    func setBrokerURL(_ url: URL?) {
        if let url {
            storage.save(url.absoluteString, .plaidSandboxBrokerURL)
        } else {
            storage.delete(.plaidSandboxBrokerURL)
        }
    }

    func setItemID(_ value: String?) {
        if let value, !value.isEmpty {
            storage.save(value, .plaidSandboxItemID)
        } else {
            storage.delete(.plaidSandboxItemID)
        }
    }

    func setTransactionsCursor(_ value: String?) {
        if let value, !value.isEmpty {
            storage.save(value, .plaidSandboxTransactionsCursor)
        } else {
            storage.delete(.plaidSandboxTransactionsCursor)
        }
    }

    func setBrokerSecret(_ value: String?) {
        if let value, !value.isEmpty {
            storage.save(value, .plaidSandboxBrokerSecret)
        } else {
            storage.delete(.plaidSandboxBrokerSecret)
        }
    }

    /// Clears the Plaid-item-linked state (item handle + `/sync` cursor)
    /// without touching the broker URL or shared secret. Used by the
    /// developer config "Clear linked item" action.
    func clearLinkedItem() {
        setItemID(nil)
        setTransactionsCursor(nil)
    }

    /// Clears every Plaid sandbox Keychain value owned by this
    /// configuration — broker URL, shared secret, item handle,
    /// cursor. Used by the developer config "Reset all" action.
    func clearAll() {
        setBrokerURL(nil)
        setBrokerSecret(nil)
        clearLinkedItem()
    }

    // MARK: - Validation

    /// Narrow validator the developer config UI and the broker-set
    /// path use to enforce the broker URL shape: must parse, must
    /// be `http(s)`, must carry a host, must not use user-info or
    /// non-empty fragments. Pure and cheap.
    nonisolated static func normalize(brokerURLCandidate raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty
        else { return nil }
        // Reject user-info in URL (`user:pass@host`) — the secret
        // lives in the dedicated Keychain slot, not the URL.
        guard components.user == nil, components.password == nil else {
            return nil
        }
        // Drop fragments; preserve path + port if present.
        var cleaned = components
        cleaned.fragment = nil
        return cleaned.url
    }
}

// MARK: - Storage seam

/// Protocol seam so tests can swap the Keychain for an in-memory
/// implementation without touching iOS Keychain state.
protocol PlaidSandboxConfigurationStorage: Sendable {
    func loadString(_ key: KeychainService.Key) -> String?
    func save(_ value: String, _ key: KeychainService.Key)
    func delete(_ key: KeychainService.Key)
}

/// Keychain-backed production storage. Thin wrapper.
struct KeychainPlaidSandboxConfigurationStorage: PlaidSandboxConfigurationStorage {
    func loadString(_ key: KeychainService.Key) -> String? {
        KeychainService.loadString(forKey: key)
    }
    func save(_ value: String, _ key: KeychainService.Key) {
        KeychainService.save(value, forKey: key)
    }
    func delete(_ key: KeychainService.Key) {
        KeychainService.delete(key: key)
    }
}
