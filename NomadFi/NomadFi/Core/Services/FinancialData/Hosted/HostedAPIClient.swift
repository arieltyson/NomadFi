import Foundation

actor HostedAPIClient {
    let endpoint: URL
    private let transport: any HostedHTTPTransport
    private let credentials: any HostedCredentialStoring
    private var refreshTask: Task<HostedSession, Error>?
    private var sessionGeneration = UUID()

    init(endpoint: URL, credentials: any HostedCredentialStoring = HostedKeychainStore(),
         transport: any HostedHTTPTransport = HostedURLSessionTransport()) throws {
        guard endpoint.scheme == "https", endpoint.host != nil, endpoint.user == nil,
              endpoint.password == nil, endpoint.query == nil, endpoint.fragment == nil else {
            throw HostedServiceError.insecureEndpoint
        }
        self.endpoint = endpoint
        self.credentials = credentials
        self.transport = transport
    }

    func challenge() async throws -> HostedChallenge {
        try await send("auth/challenge", body: [:], authenticated: false)
    }

    func signIn(challenge: HostedChallenge, identityToken: String, authorizationCode: String,
                appleSubject: String) async throws -> UUID {
        let generation = UUID()
        sessionGeneration = generation
        refreshTask?.cancel()
        refreshTask = nil
        let tokens: HostedTokens = try await send("auth/apple", body: [
            "challenge_id": challenge.challengeID.uuidString, "identity_token": identityToken,
            "authorization_code": authorizationCode,
        ], authenticated: false)
        guard sessionGeneration == generation else { throw HostedServiceError.ownerChanged }
        let session = HostedSession(endpoint: endpoint, appleSubject: appleSubject, tokens: tokens,
                                    expiresAt: .now.addingTimeInterval(tokens.expiresIn))
        try await credentials.saveSession(session)
        return tokens.userID
    }

    func session() async throws -> HostedSession? {
        guard let saved = try await credentials.session(), saved.endpoint == endpoint else { return nil }
        return saved
    }

    func signOut() async throws {
        let previous = try await session()
        sessionGeneration = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        try await credentials.saveSession(nil)
        try await credentials.saveExchange(nil)
        if let previous {
            var request = URLRequest(url: endpoint.appending(path: "auth/logout"))
            request.httpMethod = "POST"
            request.httpBody = Data("{}".utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(previous.tokens.accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await transport.data(for: request)
        }
    }

    func connections() async throws -> [HostedConnection] {
        let response: ConnectionList = try await send("connections")
        return response.connections
    }

    func beginLink(connectionID: UUID? = nil) async throws -> HostedLink {
        try await send("link", body: connectionID.map { ["connection_id": $0.uuidString] } ?? [:])
    }

    func exchange(attemptID: UUID, publicToken: String) async throws -> UUID {
        guard let session = try await session() else { throw HostedServiceError.signInRequired }
        try await credentials.saveExchange(.init(attemptID: attemptID, publicToken: publicToken,
                                                userID: session.tokens.userID, endpoint: endpoint))
        return try await resumeExchange()
    }

    func resumeExchange() async throws -> UUID {
        guard let pending = try await credentials.exchange(), let session = try await session(),
              pending.endpoint == endpoint, pending.userID == session.tokens.userID else {
            throw HostedServiceError.ownerChanged
        }
        let response: ConnectionResult = try await send("link/exchange", body: [
            "attempt_id": pending.attemptID.uuidString, "public_token": pending.publicToken,
        ])
        try await credentials.saveExchange(nil)
        return response.connectionID
    }

    func completeUpdate(_ id: UUID) async throws {
        let _: ConnectionResult = try await send("connections/\(id.uuidString)/updated", body: [:])
    }

    func requestSync(_ id: UUID) async throws {
        let _: EmptyResponse = try await send("connections/\(id.uuidString)/sync", body: [:])
    }

    func disconnect(_ id: UUID) async throws {
        let _: EmptyResponse = try await send("connections/\(id.uuidString)", method: "DELETE", body: [:])
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await send("account", method: "DELETE", body: [:])
        sessionGeneration = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        try await credentials.saveSession(nil)
        try await credentials.saveExchange(nil)
    }

    func beginSnapshot() async throws -> HostedSnapshot { try await send("snapshots", body: [:]) }
    func fiBotStatus() async throws -> HostedFiBotStatus { try await send("fibot") }
    func configureFiBot(_ input: HostedFiBotConfiguration) async throws -> HostedFiBotConfigurationResult {
        try await perform("fibot/configuration", method: "POST", data: JSONEncoder().encode(input))
    }
    func dismissFiBotAlert(_ id: UUID) async throws {
        let _: EmptyResponse = try await send("fibot/alerts/\(id.uuidString)", method: "DELETE", body: [:])
    }
    func snapshotPage(_ id: UUID, after: String = "0") async throws -> HostedSnapshotPage {
        try await send("snapshots/\(id.uuidString)", query: [.init(name: "after", value: after)])
    }
    func changes(after checkpoint: HostedCheckpoint, through: String? = nil) async throws -> HostedChanges {
        try await send("changes", query: [
            .init(name: "revision", value: checkpoint.revision), .init(name: "offset", value: String(checkpoint.offset)),
        ] + (through.map { [.init(name: "through", value: $0)] } ?? []))
    }
    func acknowledge(_ checkpoint: HostedCheckpoint, deviceID: UUID) async throws {
        let data = try JSONEncoder().encode(Acknowledgment(deviceID: deviceID, checkpoint: checkpoint))
        let _: EmptyResponse = try await perform("acknowledgments", method: "POST", data: data)
    }

    private func validSession() async throws -> HostedSession {
        guard let session = try await session() else { throw HostedServiceError.signInRequired }
        if session.expiresAt.timeIntervalSinceNow > 30 { return session }
        if let refreshTask { return try await refreshTask.value }
        let generation = sessionGeneration
        let task = Task { try await self.rotate(session, generation: generation) }
        refreshTask = task
        do {
            let refreshed = try await task.value
            guard generation == sessionGeneration else { throw HostedServiceError.ownerChanged }
            refreshTask = nil
            return refreshed
        } catch {
            if generation == sessionGeneration {
                refreshTask = nil
                try await credentials.saveSession(nil)
            }
            throw error
        }
    }

    private func rotate(_ session: HostedSession, generation: UUID) async throws -> HostedSession {
        let tokens: HostedTokens = try await send("auth/refresh", body: ["refresh_token": session.tokens.refreshToken], authenticated: false)
        guard tokens.userID == session.tokens.userID, generation == sessionGeneration else {
            throw HostedServiceError.ownerChanged
        }
        let refreshed = HostedSession(endpoint: endpoint, appleSubject: session.appleSubject, tokens: tokens,
                                      expiresAt: .now.addingTimeInterval(tokens.expiresIn))
        try await credentials.saveSession(refreshed)
        return refreshed
    }

    private func send<Response: Decodable & Sendable>(
        _ path: String, method: String? = nil, body: [String: String]? = nil,
        query: [URLQueryItem] = [], authenticated: Bool = true
    ) async throws -> Response {
        try await perform(path, method: method ?? (body == nil ? "GET" : "POST"),
                          data: try body.map { try JSONEncoder().encode($0) }, query: query, authenticated: authenticated)
    }

    private func perform<Response: Decodable & Sendable>(
        _ path: String, method: String, data: Data? = nil, query: [URLQueryItem] = [], authenticated: Bool = true
    ) async throws -> Response {
        guard var components = URLComponents(url: endpoint.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw HostedServiceError.insecureEndpoint
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw HostedServiceError.insecureEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = data
        if data != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let generation = sessionGeneration
        if authenticated {
            let session = try await validSession()
            guard generation == sessionGeneration else { throw HostedServiceError.ownerChanged }
            request.setValue("Bearer \(session.tokens.accessToken)", forHTTPHeaderField: "Authorization")
        }
        let (result, response) = try await transport.data(for: request)
        if authenticated, generation != sessionGeneration { throw HostedServiceError.ownerChanged }
        guard (200..<300).contains(response.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorResponse.self, from: result))?.error
            if response.statusCode == 401 { throw HostedServiceError.signInRequired }
            if response.statusCode == 410 { throw HostedServiceError.snapshotExpired }
            if code == "PILOT_ACCESS_REQUIRED" { throw HostedServiceError.pilotAccessRequired }
            if code == "LINK_RECOVERY_REQUIRED" { throw HostedServiceError.recoveryRequired }
            if code == "EXCHANGE_IN_PROGRESS" { throw HostedServiceError.requestInProgress }
            throw HostedServiceError.unavailable
        }
        do { return try JSONDecoder().decode(Response.self, from: result) }
        catch { throw HostedServiceError.invalidResponse }
    }

    private struct EmptyResponse: Decodable, Sendable {}
    private struct ErrorResponse: Decodable, Sendable { let error: String }
    private struct ConnectionList: Decodable, Sendable { let connections: [HostedConnection] }
    private struct ConnectionResult: Decodable, Sendable {
        let connectionID: UUID
        enum CodingKeys: String, CodingKey { case connectionID = "connection_id" }
    }
    private struct Acknowledgment: Encodable {
        let deviceID: UUID
        let checkpoint: HostedCheckpoint
        enum CodingKeys: String, CodingKey { case deviceID = "device_id", checkpoint }
    }
}
