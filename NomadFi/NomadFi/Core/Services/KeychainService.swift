// KeychainService.swift
// NomadFi
//
// Provides type-safe Keychain CRUD operations for secure storage of
// sensitive data such as API tokens, biometric state, and user preferences
// that must not be stored in UserDefaults or SwiftData.

import Foundation
import OSLog
import Security

/// A type-safe wrapper around the iOS Keychain for secure storage.
///
/// All items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` accessibility,
/// meaning they are:
/// - Only accessible when the device is unlocked
/// - Never included in iCloud Keychain sync
/// - Never included in unencrypted iTunes/Finder backups
///
/// This is the strictest accessibility level appropriate for a finance app
/// where data must never leave the physical device.
enum KeychainService {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Keychain")

    /// Keys for items stored in the Keychain.
    enum Key: String, Sendable {
        /// Whether the user has enabled biometric app lock.
        case appLockEnabled = "com.nomadfi.appLockEnabled"

        /// The user's preferred app lock timeout interval in seconds.
        case appLockTimeout = "com.nomadfi.appLockTimeout"

        /// Reserved for future API tokens (exchange rate premium, etc.).
        case apiToken = "com.nomadfi.apiToken"

        // MARK: - Plaid sandbox (Phase 5D follow-through)
        //
        // These three keys power the bounded Plaid *sandbox* proof. They
        // never hold Plaid `client_id` / `secret` — those stay on the
        // local-only broker under `tools/plaid-sandbox-broker/`. The
        // app only ever sees:
        //
        // - the broker's base URL (dev machine on the local network),
        // - an opaque item handle the broker returns after it has
        //   exchanged the Plaid public_token for an access_token,
        // - the `/transactions/sync` cursor so incremental pulls are
        //   idempotent across launches.
        //
        // Not present on production builds unless a developer configures
        // them explicitly. Cleared by `deleteAll()` as part of the
        // existing data-wipe path.

        /// Base URL for the local Plaid sandbox broker (e.g.
        /// `http://127.0.0.1:8787`). Never points at plaid.com directly.
        case plaidSandboxBrokerURL = "com.nomadfi.plaidSandboxBrokerURL"

        /// Opaque handle the broker returns in exchange for a Plaid
        /// `public_token`. The real `access_token` stays on the broker
        /// keyed by this handle.
        case plaidSandboxItemID = "com.nomadfi.plaidSandboxItemID"

        /// Persisted cursor for `/transactions/sync` so repeat runs
        /// pull incremental diffs, not full history.
        case plaidSandboxTransactionsCursor = "com.nomadfi.plaidSandboxTransactionsCursor"

        /// Shared secret the broker requires when running in
        /// developer-only LAN mode. Loopback mode does not need it.
        /// Sent as an `X-NomadFi-Broker-Secret` header on every
        /// request so a broker accidentally exposed on the LAN still
        /// rejects traffic that does not carry the developer's
        /// locally-configured value.
        case plaidSandboxBrokerSecret = "com.nomadfi.plaidSandboxBrokerSecret"
        case plaidPendingExchange = "com.nomadfi.plaidPendingExchange"
    }

    // MARK: - String Storage

    /// Saves a string value securely to the Keychain.
    ///
    /// If the key already exists, the value is updated in place.
    ///
    /// - Parameters:
    ///   - value: The string to store.
    ///   - key: The Keychain key to store it under.
    /// - Returns: `true` if the operation succeeded.
    @discardableResult
    static func save(_ value: String, forKey key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to encode string for Keychain key: \(key.rawValue, privacy: .public)")
            return false
        }
        return save(data: data, forKey: key)
    }

    /// Retrieves a string value from the Keychain.
    ///
    /// - Parameter key: The Keychain key to look up.
    /// - Returns: The stored string, or `nil` if not found.
    static func loadString(forKey key: Key) -> String? {
        guard let data = loadData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Boolean Storage

    /// Saves a boolean value to the Keychain.
    @discardableResult
    static func save(_ value: Bool, forKey key: Key) -> Bool {
        save(value ? "1" : "0", forKey: key)
    }

    /// Retrieves a boolean value from the Keychain.
    static func loadBool(forKey key: Key) -> Bool {
        loadString(forKey: key) == "1"
    }

    // MARK: - Data Storage

    /// Saves raw data to the Keychain with device-only accessibility.
    @discardableResult
    static func save(data: Data, forKey key: Key) -> Bool {
        // Attempt to update first; if the item doesn't exist, add it.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: bundleIdentifier,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet — add it
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus != errSecSuccess {
                logger.error("Keychain add failed for \(key.rawValue, privacy: .public): \(addStatus)")
                return false
            }
            return true
        }

        logger.error("Keychain update failed for \(key.rawValue, privacy: .public): \(updateStatus)")
        return false
    }

    /// Retrieves raw data from the Keychain.
    static func loadData(forKey key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: bundleIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.warning("Keychain read failed for \(key.rawValue, privacy: .public): \(status)")
            }
            return nil
        }

        return result as? Data
    }

    // MARK: - Deletion

    /// Deletes a single item from the Keychain.
    @discardableResult
    static func delete(key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: bundleIdentifier,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain delete failed for \(key.rawValue, privacy: .public): \(status)")
            return false
        }
        return true
    }

    /// Deletes all NomadFi Keychain items.
    ///
    /// Called during "Delete All My Data" to ensure a complete wipe.
    static func deleteAll() {
        let keys: [Key] = [
            .appLockEnabled,
            .appLockTimeout,
            .apiToken,
            .plaidSandboxBrokerURL,
            .plaidSandboxItemID,
            .plaidSandboxTransactionsCursor,
            .plaidSandboxBrokerSecret,
            .plaidPendingExchange,
        ]
        for key in keys {
            delete(key: key)
        }
        logger.info("All Keychain items deleted")
    }

    // MARK: - Private

    private static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.nomadfi.app"
}
