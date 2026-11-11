// HostedSyncPolicy.swift
// NomadFi
//
// When bank updates download on their own, and how loudly.

import Foundation

/// What started a download of bank updates.
enum HostedSyncTrigger: Sendable {
    /// The app did it: a screen appeared or the app came forward.
    case automatic
    /// The person asked: they tapped Update or pulled to refresh.
    case userInitiated
}

/// The rules that keep automatic refreshes quiet.
///
/// Data should stay current without the person doing anything, but
/// progress, haptics and announcements belong to updates they asked
/// for. An automatic refresh therefore runs at most once per
/// ``automaticInterval`` and never replaces "Up to date" with a
/// progress line or reports a failure over data that is still good.
enum HostedSyncPolicy {

    /// The shortest gap between automatic refreshes.
    static let automaticInterval: TimeInterval = 300

    /// How often, and how many times, to check on a newly linked bank
    /// before leaving it to the next ordinary refresh (about two minutes).
    static let firstSyncCheckInterval: Duration = .seconds(4)
    static let firstSyncChecks = 30

    /// Whether an automatic refresh is due.
    static func isAutomaticRefreshDue(state: HostedSyncState, now: Date = .now) -> Bool {
        guard case .upToDate(let date) = state else { return state != .syncing }
        return now.timeIntervalSince(date) >= automaticInterval
    }

    /// Whether a download should show "Downloading updates…". Automatic
    /// refreshes over current data stay invisible.
    static func showsProgress(for trigger: HostedSyncTrigger, state: HostedSyncState) -> Bool {
        if trigger == .userInitiated { return true }
        if case .upToDate = state { return false }
        return true
    }

    /// The state after a failed download. A quiet refresh that fails keeps
    /// the last good state; one the person asked for says why it failed.
    static func stateAfterFailure(
        _ message: String,
        trigger: HostedSyncTrigger,
        previous: HostedSyncState
    ) -> HostedSyncState {
        if trigger == .automatic, case .upToDate = previous { return previous }
        return .failed(message)
    }
}
