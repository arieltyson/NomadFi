import Foundation

protocol HostedCredentialStoring: Sendable {
    func session() async throws -> HostedSession?
    func saveSession(_ session: HostedSession?) async throws
    func exchange() async throws -> HostedExchange?
    func saveExchange(_ exchange: HostedExchange?) async throws
}

actor HostedKeychainStore: HostedCredentialStoring {
    func session() throws -> HostedSession? {
        guard let data = KeychainService.loadData(forKey: .hostedSession) else { return nil }
        return try JSONDecoder().decode(HostedSession.self, from: data)
    }
    func saveSession(_ session: HostedSession?) throws {
        try save(session, key: .hostedSession)
    }
    func exchange() throws -> HostedExchange? {
        guard let data = KeychainService.loadData(forKey: .hostedPendingExchange) else { return nil }
        return try JSONDecoder().decode(HostedExchange.self, from: data)
    }
    func saveExchange(_ exchange: HostedExchange?) throws {
        try save(exchange, key: .hostedPendingExchange)
    }
    private func save<Value: Encodable>(_ value: Value?, key: KeychainService.Key) throws {
        let succeeded: Bool
        if let value {
            succeeded = KeychainService.save(data: try JSONEncoder().encode(value), forKey: key)
        } else {
            succeeded = KeychainService.delete(key: key)
        }
        guard succeeded else { throw HostedServiceError.credentialStorageFailed }
    }
}
