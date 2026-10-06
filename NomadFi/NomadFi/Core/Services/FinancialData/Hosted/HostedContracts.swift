import Foundation

enum HostedServiceError: Error, Equatable, Sendable {
    case insecureEndpoint
    case signInRequired
    case credentialStorageFailed
    case invalidResponse
    case snapshotExpired
    case recoveryRequired
    case requestInProgress
    case unavailable
    case ownerChanged
    case migrationRequired
    case obsoleteDelivery
}

struct HostedChallenge: Decodable, Sendable {
    let challengeID: UUID
    let nonce: String
    enum CodingKeys: String, CodingKey { case challengeID = "challenge_id", nonce }
}

struct HostedTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", refreshToken = "refresh_token"
        case expiresIn = "expires_in", userID = "user_id"
    }
}

struct HostedSession: Codable, Sendable {
    let endpoint: URL
    let appleSubject: String
    let tokens: HostedTokens
    let expiresAt: Date
}

struct HostedConnection: Decodable, Sendable, Identifiable {
    let id: UUID
    let environment: String
    let institutionName: String?
    let state: String
    let lastSyncedAt: String?
    enum CodingKeys: String, CodingKey {
        case id, environment, state
        case institutionName = "institution_name", lastSyncedAt = "last_synced_at"
    }
}

struct HostedLink: Codable, Sendable {
    let linkToken: String
    let attemptID: UUID?
    let connectionID: UUID?
    let mode: String
    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token", attemptID = "attempt_id", connectionID = "connection_id", mode
    }
}

struct HostedExchange: Codable, Sendable {
    let attemptID: UUID
    let publicToken: String
    let userID: UUID
    let endpoint: URL
}

struct HostedCheckpoint: Codable, Equatable, Sendable {
    var revision: String
    var offset: Int
    static let initial = Self(revision: "0", offset: -1)
}

struct HostedPayload: Codable, Equatable, Sendable {
    var name: String?
    var type: String?
    var subtype: String?
    var currency: String?
    var current: String?
    var available: String?
    var limit: String?
    var fetchedAt: String?
    var balanceObservedAt: String?
    var accountID: String?
    var amount: String?
    var date: String?
    var authorizedDate: String?
    var merchantName: String?
    var pending: Bool?
    var pendingTransactionID: String?
    var category: String?
    var categoryDetail: String?
    enum CodingKeys: String, CodingKey {
        case name, type, subtype, currency, current, available, limit, amount, date, pending, category
        case fetchedAt = "fetched_at", balanceObservedAt = "balance_observed_at", accountID = "account_id"
        case authorizedDate = "authorized_date", merchantName = "merchant_name"
        case pendingTransactionID = "pending_transaction_id", categoryDetail = "category_detail"
    }
}

struct HostedEvent: Codable, Sendable {
    let connectionID: UUID
    let kind: String
    let externalID: String
    let payload: HostedPayload
    let removed: Bool?
    enum CodingKeys: String, CodingKey {
        case connectionID = "connection_id", kind, externalID = "external_id", payload, removed
    }
    var isRemoved: Bool { removed == true || kind.hasPrefix("removed_") }
    var entityKind: String { kind.replacingOccurrences(of: "removed_", with: "") }
    var identity: String { "\(connectionID.uuidString.lowercased())/\(entityKind)/\(externalID)" }
}

struct HostedChanges: Decodable, Sendable {
    let events: [HostedEvent]
    let through: String
    let hasMore: Bool
    let checkpoint: HostedCheckpoint
}

struct HostedSnapshot: Decodable, Sendable {
    let snapshotID: UUID
    let revision: String
    enum CodingKeys: String, CodingKey { case snapshotID = "snapshot_id", revision }
}

struct HostedSnapshotPage: Decodable, Sendable {
    let records: [HostedEvent]
    let hasMore: Bool
    let after: String
    let checkpoint: HostedCheckpoint
}
