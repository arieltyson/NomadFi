import Foundation
import SwiftData

@MainActor
@Observable
final class HostedSyncCoordinator {
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?

    func sync(client: HostedAPIClient, container: ModelContainer, homeCurrency: CurrencyCode) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        guard let session = try await client.session() else { throw HostedServiceError.signInRequired }
        let store = HostedLocalStore(container: container)
        let position = try store.position(ownerID: session.tokens.userID, endpoint: session.endpoint)
        var checkpoint = position?.checkpoint ?? .initial
        var events: [HostedEvent] = []
        if position?.bootstrapped != true {
            let snapshot = try await client.beginSnapshot()
            var after = "0"
            while true {
                let page = try await client.snapshotPage(snapshot.snapshotID, after: after)
                events += page.records
                guard events.count <= 200_000 else { throw HostedServiceError.invalidResponse }
                checkpoint = page.checkpoint
                if !page.hasMore { break }
                guard page.after != after else { throw HostedServiceError.invalidResponse }
                after = page.after
            }
        }
        var through: String?
        while true {
            let page = try await client.changes(after: checkpoint, through: through)
            events += page.events
            guard events.count <= 200_000 else { throw HostedServiceError.invalidResponse }
            through = page.through
            if page.hasMore, page.checkpoint == checkpoint { throw HostedServiceError.invalidResponse }
            checkpoint = page.checkpoint
            if !page.hasMore { break }
        }
        guard try await client.session()?.tokens.userID == session.tokens.userID else { throw HostedServiceError.ownerChanged }
        let committed = try store.apply(events, checkpoint: checkpoint, ownerID: session.tokens.userID,
                                        endpoint: session.endpoint, homeCurrency: homeCurrency)
        lastSyncedAt = .now
        try await client.acknowledge(committed.checkpoint, deviceID: committed.deviceID)
    }
}
