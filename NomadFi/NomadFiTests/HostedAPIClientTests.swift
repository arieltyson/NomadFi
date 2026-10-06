import Foundation
import Testing
@testable import NomadFi

private actor HostedMemoryCredentials: HostedCredentialStoring {
    var saved: HostedSession?
    var pending: HostedExchange?
    init(_ session: HostedSession? = nil) { saved = session }
    func session() -> HostedSession? { saved }
    func saveSession(_ session: HostedSession?) { saved = session }
    func exchange() -> HostedExchange? { pending }
    func saveExchange(_ exchange: HostedExchange?) { pending = exchange }
}

private actor HostedTestTransport: HostedHTTPTransport {
    var refreshCount = 0
    var requests: [URLRequest] = []
    let userID: UUID
    var failExchange = false
    var failRefresh = false
    init(userID: UUID) { self.userID = userID }
    func setExchangeFailure(_ value: Bool) { failExchange = value }
    func setRefreshFailure(_ value: Bool) { failRefresh = value }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url!.path
        var status = 200
        let data: Data
        switch path {
        case "/auth/refresh", "/auth/apple":
            refreshCount += 1
            try await Task.sleep(for: .milliseconds(20))
            if failRefresh { throw URLError(.networkConnectionLost) }
            data = try JSONEncoder().encode(HostedTokens(accessToken: "synthetic-access", refreshToken: "synthetic-refresh",
                                                        expiresIn: 900, userID: userID))
        case "/link/exchange":
            if failExchange { throw URLError(.networkConnectionLost) }
            data = Data("{\"connection_id\":\"\(userID.uuidString)\"}".utf8)
        case "/connections": data = Data("{\"connections\":[]}".utf8)
        case "/auth/logout": data = Data("{}".utf8)
        default: status = 404; data = Data("{}".utf8)
        }
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

struct HostedAPIClientTests {
    private let endpoint = URL(string: "https://example.test")!

    private func savedSession(userID: UUID = UUID(), expired: Bool = false) -> HostedSession {
        .init(endpoint: endpoint, appleSubject: "synthetic-subject",
              tokens: .init(accessToken: "old-access", refreshToken: "old-refresh", expiresIn: 900, userID: userID),
              expiresAt: .now.addingTimeInterval(expired ? -1 : 900))
    }

    @Test func rejectsInsecureOrCredentialBearingEndpoints() {
        for value in ["http://example.test", "https://user:password@example.test", "https://example.test?secret=example"] {
            #expect(throws: HostedServiceError.insecureEndpoint) { try HostedAPIClient(endpoint: URL(string: value)!) }
        }
    }

    @Test func concurrentRequestsRefreshOnceAndPersistBeforeUse() async throws {
        let session = savedSession(expired: true)
        let credentials = HostedMemoryCredentials(session)
        let transport = HostedTestTransport(userID: session.tokens.userID)
        let client = try HostedAPIClient(endpoint: endpoint, credentials: credentials, transport: transport)
        async let first = client.connections()
        async let second = client.connections()
        _ = try await (first, second)
        #expect(await transport.refreshCount == 1)
        #expect(await credentials.session()?.tokens.accessToken == "synthetic-access")
        let requests = await transport.requests.filter { $0.url?.path == "/connections" }
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-access" })
    }

    @Test func lostRefreshResponseRequiresSignInInsteadOfReplayingCredential() async throws {
        let session = savedSession(expired: true)
        let credentials = HostedMemoryCredentials(session)
        let transport = HostedTestTransport(userID: session.tokens.userID)
        await transport.setRefreshFailure(true)
        let client = try HostedAPIClient(endpoint: endpoint, credentials: credentials, transport: transport)
        await #expect(throws: (any Error).self) { try await client.connections() }
        #expect(await credentials.session() == nil)
        await #expect(throws: HostedServiceError.signInRequired) { try await client.connections() }
        #expect(await transport.refreshCount == 1)
    }

    @Test func pendingExchangeSurvivesNetworkFailureAndIsBoundToOwner() async throws {
        let session = savedSession(), attempt = UUID()
        let credentials = HostedMemoryCredentials(session)
        let transport = HostedTestTransport(userID: session.tokens.userID)
        let client = try HostedAPIClient(endpoint: endpoint, credentials: credentials, transport: transport)
        await transport.setExchangeFailure(true)
        await #expect(throws: (any Error).self) { try await client.exchange(attemptID: attempt, publicToken: "synthetic-public") }
        #expect(await credentials.exchange()?.attemptID == attempt)
        await credentials.saveSession(savedSession())
        await #expect(throws: HostedServiceError.ownerChanged) { try await client.resumeExchange() }
        await credentials.saveSession(session)
        await transport.setExchangeFailure(false)
        #expect(try await client.resumeExchange() == session.tokens.userID)
        #expect(await credentials.exchange() == nil)
    }

    @Test func signOutCannotBeUndoneByAnInflightRefresh() async throws {
        let session = savedSession(expired: true)
        let credentials = HostedMemoryCredentials(session)
        let transport = HostedTestTransport(userID: session.tokens.userID)
        let client = try HostedAPIClient(endpoint: endpoint, credentials: credentials, transport: transport)
        let pending = Task { try await client.connections() }
        while await transport.refreshCount == 0 { await Task.yield() }
        try await client.signOut()
        _ = await pending.result
        #expect(await credentials.session() == nil)
        #expect(await transport.requests.filter { $0.url?.path == "/connections" }.isEmpty)
    }
}
