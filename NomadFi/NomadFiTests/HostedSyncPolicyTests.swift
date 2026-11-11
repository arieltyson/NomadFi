import Foundation
import Testing
@testable import NomadFi

struct HostedSyncPolicyTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func automaticRefreshWaitsOutItsInterval() {
        let recent = HostedSyncState.upToDate(now.addingTimeInterval(-HostedSyncPolicy.automaticInterval + 1))
        let stale = HostedSyncState.upToDate(now.addingTimeInterval(-HostedSyncPolicy.automaticInterval))
        #expect(!HostedSyncPolicy.isAutomaticRefreshDue(state: recent, now: now))
        #expect(HostedSyncPolicy.isAutomaticRefreshDue(state: stale, now: now))
    }

    @Test func automaticRefreshRunsWhenNothingIsLoadedOrTheLastOneFailed() {
        #expect(HostedSyncPolicy.isAutomaticRefreshDue(state: .idle, now: now))
        #expect(HostedSyncPolicy.isAutomaticRefreshDue(state: .failed("x"), now: now))
        #expect(!HostedSyncPolicy.isAutomaticRefreshDue(state: .syncing, now: now))
    }

    @Test func onlyRequestedDownloadsReplaceUpToDateWithProgress() {
        let current = HostedSyncState.upToDate(now)
        #expect(!HostedSyncPolicy.showsProgress(for: .automatic, state: current))
        #expect(HostedSyncPolicy.showsProgress(for: .userInitiated, state: current))
        #expect(HostedSyncPolicy.showsProgress(for: .automatic, state: .idle))
    }

    @Test func aQuietFailureKeepsTheLastGoodState() {
        let current = HostedSyncState.upToDate(now)
        #expect(HostedSyncPolicy.stateAfterFailure("offline", trigger: .automatic, previous: current) == current)
        #expect(HostedSyncPolicy.stateAfterFailure("offline", trigger: .userInitiated, previous: current) == .failed("offline"))
        #expect(HostedSyncPolicy.stateAfterFailure("offline", trigger: .automatic, previous: .idle) == .failed("offline"))
    }
}
