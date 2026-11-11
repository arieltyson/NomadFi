import AuthenticationServices
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class HostedBankingController {
    let client: HostedAPIClient
    let redirectURI: URL
    let privacyPolicyURL: URL?
    let hostingRegion: String
    let backupRetentionDays: Int
    private let presenter: any PlaidLinkPresenting
    private let syncCoordinator = HostedSyncCoordinator()
    private(set) var challenge: HostedChallenge?
    private(set) var userID: UUID?
    private(set) var connections: [HostedConnection] = []
    private(set) var isWorking = false
    private(set) var message: String?
    private(set) var migrationReview: HostedLegacyMigration?
    /// Debug builds only: the Apple user identifier the server just
    /// refused, so the owner can add it to `APPLE_ALLOWED_SUBJECTS`.
    /// The server never reveals it; it comes from this device's own
    /// Apple credential.
    private(set) var refusedAppleSubject: String?
    /// The state of downloading bank updates, shown at the top of Bank Connections.
    private(set) var syncState: HostedSyncState = .idle
    /// Counts downloads the person asked for that have finished, so the
    /// interface can give feedback for those and stay silent for the rest.
    private(set) var userSyncOutcomes = 0
    /// Counts banks linked in this session, so the screen can follow each
    /// new one until its first history arrives.
    private(set) var linkCompletions = 0
    private var isDownloading = false
    private var isPreparing = false
    /// A bank link finished in Plaid but the server never saved it.
    private(set) var hasPendingExchange = false
    /// Bank records from the retired on-device connection are still stored,
    /// which blocks hosted updates until they are reviewed or removed.
    private(set) var hasLegacyRecords = false

    init(client: HostedAPIClient, redirectURI: URL, presenter: any PlaidLinkPresenting,
         privacyPolicyURL: URL? = nil, hostingRegion: String = "Not configured", backupRetentionDays: Int = 0) {
        self.client = client
        self.redirectURI = redirectURI
        self.presenter = presenter
        self.privacyPolicyURL = privacyPolicyURL
        self.hostingRegion = hostingRegion
        self.backupRetentionDays = backupRetentionDays
    }

    static func configured(bundle: Bundle = .main) -> HostedBankingController? {
        #if DEBUG || HOSTED_BANKING
        guard let raw = bundle.object(forInfoDictionaryKey: "NomadFiHostedBackendURL") as? String,
              let endpoint = URL(string: raw), let client = try? HostedAPIClient(endpoint: endpoint),
              let redirect = bundle.object(forInfoDictionaryKey: "NomadFiPlaidRedirectURI") as? String,
              let uri = URL(string: redirect), uri.scheme == "https", uri.host != nil,
              let policy = bundle.object(forInfoDictionaryKey: "NomadFiHostedPrivacyPolicyURL") as? String,
              let policyURL = URL(string: policy), policyURL.scheme == "https", policyURL.host != nil,
              let region = bundle.object(forInfoDictionaryKey: "NomadFiHostedRegion") as? String, !region.isEmpty,
              let days = bundle.object(forInfoDictionaryKey: "NomadFiHostedBackupRetentionDays") as? Int,
              (0...90).contains(days) else { return nil }
        return HostedBankingController(client: client, redirectURI: uri, presenter: PlaidLinkKitPresenter(),
            privacyPolicyURL: policyURL, hostingRegion: region, backupRetentionDays: days)
        #else
        return nil
        #endif
    }

    /// Loads the session and connections.
    /// - Parameter showsActivity: Pass `false` for a background refresh, so
    ///   buttons don't dim while nothing the person asked for is happening.
    func prepare(showsActivity: Bool = true) async {
        guard !isWorking, !isPreparing else { return }
        isPreparing = true
        if showsActivity { isWorking = true }
        defer {
            isPreparing = false
            if showsActivity { isWorking = false }
        }
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
                hasPendingExchange = await client.hasPendingExchange()
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
            do {
                userID = try await client.signIn(challenge: challenge, identityToken: token,
                                                 authorizationCode: code, appleSubject: identity.user)
            } catch HostedServiceError.pilotAccessRequired {
                #if DEBUG
                refusedAppleSubject = identity.user
                #endif
                throw HostedServiceError.pilotAccessRequired
            }
            refusedAppleSubject = nil
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
                        self.hasPendingExchange = false
                        self.connections = try await self.client.connections()
                        self.message = nil
                        self.linkCompletions += 1
                    case .cancelled: KeychainService.delete(key: .hostedPendingLink)
                    case .failed: self.message = "The bank connection didn't finish. Your other banks are unaffected."
                    }
                } catch {
                    self.hasPendingExchange = await self.client.hasPendingExchange()
                    self.report(error)
                }
            }
        }
    }

    func retryExchange() async {
        await work {
            _ = try await self.client.resumeExchange()
            KeychainService.delete(key: .hostedPendingLink)
            self.hasPendingExchange = false
            self.connections = try await self.client.connections()
            self.message = nil
        }
    }

    /// Downloads completed bank updates and saves them on this iPhone.
    ///
    /// Progress and the outcome go to ``syncState`` rather than the
    /// general message, so the result appears on the line the person
    /// is looking at.
    func sync(container: ModelContainer, trigger: HostedSyncTrigger = .userInitiated) async {
        guard userID != nil, !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }
        refreshLocalState(container: container)
        let previous = syncState
        if HostedSyncPolicy.showsProgress(for: trigger, state: previous) { syncState = .syncing }
        do {
            let profiles = try container.mainContext.fetch(FetchDescriptor<JurisdictionProfile>())
            let currency = profiles.first(where: \.isHome)?.currencyCode ?? .usd
            try await syncCoordinator.sync(client: client, container: container, homeCurrency: currency)
            connections = try await client.connections()
            syncState = .upToDate(.now)
        } catch {
            if case .signInRequired = error as? HostedServiceError { requireSignIn() }
            syncState = HostedSyncPolicy.stateAfterFailure(
                HostedErrorMessage.text(for: error), trigger: trigger, previous: previous
            )
        }
        if trigger == .userInitiated { userSyncOutcomes += 1 }
        refreshLocalState(container: container)
    }

    /// Follows a newly linked bank until the server's first fetch lands,
    /// then downloads it. The row shows progress meanwhile, so this stays
    /// quiet; it gives up after a couple of minutes and leaves the rest to
    /// the next refresh.
    func followNewConnection(container: ModelContainer) async {
        for _ in 0..<HostedSyncPolicy.firstSyncChecks {
            try? await Task.sleep(for: HostedSyncPolicy.firstSyncCheckInterval)
            guard !Task.isCancelled, userID != nil else { return }
            guard let latest = try? await client.connections() else { continue }
            connections = latest
            if latest.allSatisfy({ $0.lastSyncedDate != nil || $0.state != "connected" }) {
                await sync(container: container, trigger: .automatic)
                return
            }
        }
    }

    /// Keeps data current without drawing attention: runs at most once per
    /// ``HostedSyncPolicy/automaticInterval``, without progress, haptics or
    /// dimmed buttons unless nothing has loaded yet.
    func refreshAutomatically(container: ModelContainer) async {
        refreshLocalState(container: container)
        guard userID == nil || HostedSyncPolicy.isAutomaticRefreshDue(state: syncState) else { return }
        await prepare(showsActivity: userID == nil)
        await sync(container: container, trigger: .automatic)
    }

    /// Re-reads what is stored on this iPhone that changes which actions apply.
    func refreshLocalState(container: ModelContainer) {
        let legacyKind: String? = HostedLegacyMigration.legacyKind
        let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.providerLinkKindRawValue == legacyKind })
        hasLegacyRecords = ((try? container.mainContext.fetchCount(descriptor)) ?? 0) > 0
    }

    func prepareLegacyMigration(container: ModelContainer) async {
        await work {
            guard let session = try await self.client.session() else { throw HostedServiceError.signInRequired }
            let snapshot = try await self.client.beginSnapshot()
            var events: [HostedEvent] = [], after = "0", checkpoint = HostedCheckpoint.initial
            while true {
                let page = try await self.client.snapshotPage(snapshot.snapshotID, after: after)
                events += page.records; checkpoint = page.checkpoint
                guard events.count <= 200_000 else { throw HostedServiceError.invalidResponse }
                if !page.hasMore { break }
                guard page.after != after else { throw HostedServiceError.invalidResponse }
                after = page.after
            }
            guard try await self.client.session()?.tokens.userID == session.tokens.userID else { throw HostedServiceError.ownerChanged }
            self.migrationReview = try HostedLegacyMigration.prepare(events: events, checkpoint: checkpoint,
                ownerID: session.tokens.userID, endpoint: session.endpoint, container: container)
        }
    }

    func confirmLegacyMigration(container: ModelContainer) async {
        await work {
            guard let review = self.migrationReview, let session = try await self.client.session(),
                  session.tokens.userID == review.ownerID, session.endpoint == review.endpoint else { throw HostedServiceError.ownerChanged }
            let profiles = try container.mainContext.fetch(FetchDescriptor<JurisdictionProfile>())
            let position = try HostedLocalStore(container: container).apply(review.events, checkpoint: review.checkpoint,
                ownerID: review.ownerID, endpoint: review.endpoint, homeCurrency: profiles.first(where: \.isHome)?.currencyCode ?? .usd,
                reviewedMigration: review)
            self.migrationReview = nil
            _ = KeychainService.delete(key: .plaidSandboxItemID)
            _ = KeychainService.delete(key: .plaidSandboxTransactionsCursor)
            try await self.client.acknowledge(position.checkpoint, deviceID: position.deviceID)
            self.message = "Existing accounts and history now use hosted updates. The old bank Item has not been revoked."
        }
    }

    func cancelLegacyMigration() { migrationReview = nil }

    func refreshOnForeground(container: ModelContainer) async {
        guard (try? await client.session()) != nil else { return }
        await refreshAutomatically(container: container)
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
            self.syncState = .idle
            self.message = nil
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
        if case .signInRequired = error as? HostedServiceError { requireSignIn() }
        message = HostedErrorMessage.text(for: error)
    }

    private func requireSignIn() {
        userID = nil
        connections = []
        Task { challenge = try? await client.challenge() }
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
