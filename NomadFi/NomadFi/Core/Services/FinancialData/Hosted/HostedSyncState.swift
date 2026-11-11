// HostedSyncState.swift
// NomadFi
//
// What the last download of hosted bank updates did.

import Foundation

/// The state of downloading bank updates from the hosted service,
/// shown as one line at the top of Bank Connections.
enum HostedSyncState: Equatable, Sendable {
    /// Nothing has been downloaded in this session yet.
    case idle
    /// A download is in progress.
    case syncing
    /// The last download finished and was saved on this iPhone.
    case upToDate(Date)
    /// The last download failed, with a sentence saying why.
    case failed(String)

    var isSyncing: Bool { self == .syncing }
}
