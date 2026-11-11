import Foundation
import Testing
@testable import NomadFi

struct HostedPresentationTests {

    @Test func everyServiceErrorHasItsOwnPlainSentence() {
        let errors: [HostedServiceError] = [
            .migrationRequired, .ownerChanged, .signInRequired, .recoveryRequired, .requestInProgress,
            .pilotAccessRequired, .rateLimited, .snapshotExpired, .invalidResponse, .credentialStorageFailed, .unavailable,
        ]
        let messages = errors.map { HostedErrorMessage.text(for: $0) }
        #expect(Set(messages).count == messages.count)
        #expect(messages.allSatisfy { !$0.isEmpty && $0.hasSuffix(".") })
    }

    @Test func rateLimitingSaysToWait() {
        #expect(HostedErrorMessage.text(for: HostedServiceError.rateLimited).contains("minute"))
    }

    @Test func beingOfflineIsNotReportedAsAServerFault() {
        let offline = HostedErrorMessage.text(for: URLError(.notConnectedToInternet))
        #expect(offline.contains("offline"))
        #expect(offline != HostedErrorMessage.text(for: HostedServiceError.unavailable))
    }

    @Test func serverStatesMapToStatuses() {
        #expect(HostedConnectionStatus(rawValue: "connected") == .connected)
        #expect(HostedConnectionStatus(rawValue: "reconnect_required") == .needsSignIn)
        #expect(HostedConnectionStatus(rawValue: "revoking") == .disconnecting)
        #expect(HostedConnectionStatus(rawValue: "disconnected") == .disconnected)
        #expect(HostedConnectionStatus(rawValue: "something_new") == .unknown)
    }

    @Test func timestampsShowOnlyTheTimeToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 18)))
        let earlierToday = try #require(calendar.date(byAdding: .hour, value: -2, to: now))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        #expect(HostedTimestamp.text(earlierToday, now: now, calendar: calendar) == earlierToday.formatted(.dateTime.hour().minute()))
        #expect(HostedTimestamp.text(yesterday, now: now, calendar: calendar) != yesterday.formatted(.dateTime.hour().minute()))
    }

    @Test func serverTimestampsParseWithOrWithoutFractionalSeconds() throws {
        let data = Data(#"[{"id":"7B4F2D1E-0C1A-4E2B-9C7D-2F3A4B5C6D7E","environment":"sandbox","institution_name":"Bank","state":"connected","last_synced_at":"2026-11-11T00:08:02.103Z"},{"id":"8B4F2D1E-0C1A-4E2B-9C7D-2F3A4B5C6D7E","environment":"sandbox","institution_name":null,"state":"connected","last_synced_at":"2026-11-11T00:08:02Z"}]"#.utf8)
        let connections = try JSONDecoder().decode([HostedConnection].self, from: data)
        #expect(connections.allSatisfy { $0.lastSyncedDate != nil })
    }
}
