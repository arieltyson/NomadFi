// HostedConnectionStatus.swift
// NomadFi
//
// How one hosted bank connection is doing, in words and a symbol.

import SwiftUI

/// The state of a hosted bank connection, from the server's raw value.
enum HostedConnectionStatus: Equatable {
    case connected
    case needsSignIn
    case disconnecting
    case disconnected
    case unknown

    init(rawValue: String) {
        self = switch rawValue {
        case "connected": .connected
        case "reconnect_required": .needsSignIn
        case "revoking": .disconnecting
        case "disconnected": .disconnected
        default: .unknown
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .connected: "Connected"
        case .needsSignIn: "Needs sign-in"
        case .disconnecting: "Disconnecting"
        case .disconnected: "Disconnected"
        case .unknown: "Status unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .connected: "checkmark.circle.fill"
        case .needsSignIn: "exclamationmark.circle.fill"
        case .disconnecting, .unknown: "circle.dotted"
        case .disconnected: "minus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .connected: ColorTokens.positive
        case .needsSignIn: ColorTokens.warning
        case .disconnecting, .disconnected, .unknown: ColorTokens.neutral
        }
    }
}
