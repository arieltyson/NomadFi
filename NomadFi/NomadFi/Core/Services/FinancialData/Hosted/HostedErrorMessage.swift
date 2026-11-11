// HostedErrorMessage.swift
// NomadFi
//
// One plain sentence for each way the hosted service can fail.

import Foundation

/// Turns a hosted-banking failure into a short sentence that says what
/// happened and, where it helps, what to do. Kept free of UI so every
/// message can be tested.
enum HostedErrorMessage {

    static func text(for error: any Error) -> String {
        if let urlError = error as? URLError {
            return urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost
                ? String(localized: "You're offline. Bank data on this iPhone is still available.")
                : String(localized: "NomadFi couldn't reach its server. Try again in a moment.")
        }
        return switch error as? HostedServiceError {
        case .migrationRequired:
            String(localized: "Older bank records on this iPhone need to be reviewed before new updates can be saved.")
        case .ownerChanged:
            String(localized: "This iPhone's bank data belongs to a different account. Sign in with that account.")
        case .signInRequired:
            String(localized: "Sign in with Apple again to continue.")
        case .recoveryRequired:
            String(localized: "This connection couldn't be finished automatically. Connect the bank again.")
        case .requestInProgress:
            String(localized: "The connection is still finishing. Try again shortly.")
        case .pilotAccessRequired:
            String(localized: "This Apple Account isn't on NomadFi's pilot yet.")
        case .rateLimited:
            String(localized: "Too many requests. Try again in a minute.")
        case .snapshotExpired, .obsoleteDelivery:
            String(localized: "The download was interrupted. Try again.")
        case .invalidResponse:
            String(localized: "The server sent something unexpected. Try again.")
        case .credentialStorageFailed:
            String(localized: "NomadFi couldn't save to the Keychain. Unlock your iPhone and try again.")
        case .insecureEndpoint, .unavailable, nil:
            String(localized: "NomadFi's server is unavailable. Bank data on this iPhone is still available.")
        }
    }
}
