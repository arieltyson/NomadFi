import Foundation

struct HostedFiBotSettings: Codable, Sendable {
    var categories = ["cash_shortfall", "stale_context"]
    var quietStart = 22
    var quietEnd = 8
    var timeZone = TimeZone.current.identifier
    var snoozedUntil: String?
}
struct HostedFiBotConfiguration: Encodable, Sendable {
    let consent: Bool
    var expectedRevision: String = "0"
    var context: FiBotFinancialContext?
    var policy: FiBotPolicy?
    var settings: HostedFiBotSettings?
}
struct HostedFiBotConfigurationResult: Decodable, Sendable {
    let enabled: Bool
    let revision: String?
}
struct HostedFiBotStatus: Decodable, Sendable {
    let enabled: Bool
    let revision: String
    let settings: HostedFiBotSettings?
    let alerts: [HostedFiBotAlert]
}
struct HostedFiBotAlert: Identifiable, Decodable, Sendable {
    let id: UUID
    let category: String
    let decision: FiBotDecision
    let createdAt: String
    enum CodingKeys: String, CodingKey { case id, category, decision; case createdAt = "created_at" }
}
struct HostedFiBotConsent: Codable, Sendable {
    let userID: UUID
    let endpoint: URL
    static func load() throws -> Self? {
        guard let data = KeychainService.loadData(forKey: .hostedFiBotConsent) else { return nil }
        return try JSONDecoder().decode(Self.self, from: data)
    }
    func save() throws {
        guard KeychainService.save(data: try JSONEncoder().encode(self), forKey: .hostedFiBotConsent) else {
            throw HostedServiceError.unavailable
        }
    }
    @MainActor static func disableIfNeeded(using controller: HostedBankingController?) async throws {
        let saved = try load()
        guard let controller, let session = try await controller.client.session() else {
            if saved != nil { throw HostedServiceError.signInRequired }
            return
        }
        if let saved, session.tokens.userID != saved.userID || session.endpoint != saved.endpoint {
            throw HostedServiceError.ownerChanged
        }
        _ = try await controller.client.configureFiBot(.init(consent: false))
        guard KeychainService.delete(key: .hostedFiBotConsent) else { throw HostedServiceError.unavailable }
    }
}
