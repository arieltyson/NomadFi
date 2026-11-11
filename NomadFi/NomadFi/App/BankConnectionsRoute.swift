// BankConnectionsRoute.swift
// NomadFi
//
// Opens Settings › Financial Connections › Bank Connections, once.

import Foundation

/// Routes the app to Bank Connections, as when onboarding finishes with
/// "connect a bank". Selects the Settings tab and leaves a one-shot
/// request that Settings and Financial Connections follow and clear.
enum BankConnectionsRoute {

    /// The shared key holding the pending request.
    static let storageKey = "nomadfi.settings.pendingBankConnections"

    /// Selects Settings and asks it to open Bank Connections.
    @MainActor
    static func request(in defaults: UserDefaults = AppRoutingDefaults.shared) {
        defaults.set(MainTabSelection.settings.rawValue, forKey: MainTabSelection.storageKey)
        defaults.set(true, forKey: storageKey)
    }
}
