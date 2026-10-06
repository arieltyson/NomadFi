import AuthenticationServices
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class HostedBankingController {
    let client: HostedAPIClient
    let redirectURI: URL
    private let presenter: any PlaidLinkPresenting
    private let syncCoordinator = HostedSyncCoordinator()
    private(set) var challenge: HostedChallenge?
    private(set) var userID: UUID?
    private(set) var connections: [HostedConnection] = []
    private(set) var isWorking = false
    private(set) var message: String?

    init(client: HostedAPIClient, redirectURI: URL, presenter: any PlaidLinkPresenting) {
        self.client = client
        self.redirectURI = redirectURI
        self.presenter = presenter
    }

    static func configured(bundle: Bundle = .main) -> HostedBankingController? {
        #if DEBUG || HOSTED_BANKING
        guard let raw = bundle.object(forInfoDictionaryKey: "NomadFiHostedBackendURL") as? String,
              let endpoint = URL(string: raw), let client = try? HostedAPIClient(endpoint: endpoint),
              let redirect = bundle.object(forInfoDictionaryKey: "NomadFiPlaidRedirectURI") as? String,
              let uri = URL(string: redirect), uri.scheme == "https", uri.host != nil else { return nil }
        return HostedBankingController(client: client, redirectURI: uri, presenter: PlaidLinkKitPresenter())
        #else
        return nil
        #endif
    }

    func prepare() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            if let session = try await client.session() {
                let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: session.appleSubject)
                guard state == .authorized else {
                    try await client.signOut()
                    userID = nil
                    connections = []
                    challenge = try await client.challenge()
                    return
                }
                userID = session.tokens.userID
                connections = try await client.connections()
            } else {
                userID = nil
                challenge = try await client.challenge()
            }
        } catch { report(error) }
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, any Error>) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let authorization = try result.get()
            guard let identity = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let challenge, let token = identity.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                  let code = identity.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
                throw HostedServiceError.signInRequired
            }
            userID = try await client.signIn(challenge: challenge, identityToken: token,
                                             authorizationCode: code, appleSubject: identity.user)
            self.challenge = nil
            connections = try await client.connections()
            message = nil
        } catch {
            report(error)
            challenge = try? await client.challenge()
        }
    }

    func startLink(connectionID: UUID? = nil) async {
        guard !isWorking, let userID else { return }
        isWorking = true
        do {
            let link = try await client.beginLink(connectionID: connectionID)
            let pending = PendingLink(ownerID: userID, endpoint: client.endpoint, link: link, createdAt: .now)
            guard KeychainService.save(data: try JSONEncoder().encode(pending), forKey: .hostedPendingLink) else {
                throw HostedServiceError.credentialStorageFailed
            }
            present(pending)
        } catch { isWorking = false; report(error) }
    }

    func handle(_ url: URL) -> Bool {
        guard url.scheme == "https", url.host == redirectURI.host, url.path == redirectURI.path,
              url.port == redirectURI.port, url.user == nil, url.password == nil else { return false }
        if presenter.handle(redirectURI: url) { return true }
        guard let data = KeychainService.loadData(forKey: .hostedPendingLink),
              let pending = try? JSONDecoder().decode(PendingLink.self, from: data),
              pending.endpoint == client.endpoint, Date.now.timeIntervalSince(pending.createdAt) < 14400 else { return false }
        Task {
            guard let session = try? await client.session(), session.tokens.userID == pending.ownerID else { return }
            userID = session.tokens.userID
            isWorking = true
            present(pending, redirect: url)
        }
        return true
    }

    private func present(_ pending: PendingLink, redirect: URL? = nil) {
        presenter.present(.init(linkToken: pending.link.linkToken, receivedRedirectURI: redirect)) { [weak self] outcome in
            guard let self else { return }
            Task {
                defer { self.isWorking = false }
                do {
                    switch outcome {
                    case .success(let token):
                        if let connectionID = pending.link.connectionID { try await self.client.completeUpdate(connectionID) }
                        else if let attemptID = pending.link.attemptID { _ = try await self.client.exchange(attemptID: attemptID, publicToken: token) }
                        else { throw HostedServiceError.invalidResponse }
                        KeychainService.delete(key: .hostedPendingLink)
                        self.connections = try await self.client.connections()
                        self.message = "Connection saved. Bank history may take a few minutes to arrive."
                    case .cancelled: KeychainService.delete(key: .hostedPendingLink)
                    case .failed: self.message = "The bank connection needs another attempt. Your existing connections are still saved."
                    }
                } catch { self.report(error) }
            }
        }
    }

    func retryExchange() async {
        await work {
            _ = try await self.client.resumeExchange()
            KeychainService.delete(key: .hostedPendingLink)
            self.connections = try await self.client.connections()
            self.message = "Connection saved."
        }
    }

    func sync(container: ModelContainer) async {
        await work {
            let profiles = try container.mainContext.fetch(FetchDescriptor<JurisdictionProfile>())
            let currency = profiles.first(where: \.isHome)?.currencyCode ?? .usd
            try await self.syncCoordinator.sync(client: self.client, container: container, homeCurrency: currency)
            self.connections = try await self.client.connections()
            self.message = "Downloaded bank updates are saved on this iPhone."
        }
    }

    func refreshOnForeground(container: ModelContainer) async {
        guard (try? await client.session()) != nil else { return }
        await prepare()
        if userID != nil { await sync(container: container) }
    }

    func disconnect(_ connectionID: UUID) async {
        await work {
            try await self.client.disconnect(connectionID)
            self.connections = try await self.client.connections()
        }
    }

    func signOut() async {
        await work {
            try await self.client.signOut()
            KeychainService.delete(key: .hostedPendingLink)
            self.userID = nil
            self.connections = []
            self.challenge = try await self.client.challenge()
            self.message = "Signed out. Downloaded records remain in your protected local vault."
        }
    }

    func deleteHostedAccount() async throws {
        try await client.deleteAccount()
        KeychainService.delete(key: .hostedPendingLink)
        userID = nil
        connections = []
        message = "Hosted deletion is queued. Bank access is stopped while authorizations are revoked."
    }

    private func work(_ action: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do { try await action() } catch { report(error) }
    }
    private func report(_ error: any Error) {
        switch error as? HostedServiceError {
        case .migrationRequired:
            message = "Your existing bank history needs a verified migration before hosted records can be imported."
        case .ownerChanged:
            message = "This local vault belongs to a different hosted account. Sign in with its original account."
        case .signInRequired:
            userID = nil
            message = "Sign in with Apple again to continue."
            Task { challenge = try? await client.challenge() }
        case .recoveryRequired:
            message = "The connection could not be recovered automatically. Its Plaid authorization must be checked before linking again."
        case .requestInProgress: message = "The connection is still finishing. Retry shortly."
        default: message = "The hosted service is unavailable. Saved local records are still available."
        }
    }
    private struct PendingLink: Codable {
        let ownerID: UUID
        let endpoint: URL
        let link: HostedLink
        let createdAt: Date
    }
}

extension EnvironmentValues {
    @Entry var hostedBanking: HostedBankingController? = nil
}
