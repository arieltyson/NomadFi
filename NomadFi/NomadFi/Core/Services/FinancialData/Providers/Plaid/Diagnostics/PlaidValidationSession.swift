// PlaidValidationSession.swift
// NomadFi
//
// Value types for the DEBUG-only Phase 5D real-device validation
// recorder. The whole diagnostics layer is compiled into DEBUG
// builds only; the production app never sees these types.
//
// Design goals:
// - Structured enough that Claude can read an exported JSON/Markdown
//   artifact and decide pass / fail on criterion 5.
// - Redacted by construction: the API accepts only the narrow detail
//   map defined here; it never stores Plaid `public_token`,
//   `access_token`, broker URLs with user-info, or shared secrets.
// - Serializable via plain `JSONEncoder`, so exports are deterministic
//   and round-trip cleanly through pasted JSON.

#if DEBUG

import Foundation

// MARK: - Session

/// One real-device validation session. Accumulates events in
/// chronological order. Every mutation happens through the
/// ``PlaidValidationRecorder``; the struct itself is a value type
/// so tests can assert on a snapshot safely.
struct PlaidValidationSession: Sendable, Equatable, Codable {

    /// Schema version of the exported artifact. Bumped when the
    /// event shape changes so future recorders can tell.
    static let schemaVersion: Int = 1

    let id: UUID
    let startedAt: Date

    /// Populated by ``PlaidValidationRecorder/endSession(result:note:)``.
    var endedAt: Date?

    /// Chronological event log.
    var events: [PlaidValidationEvent]

    /// Final self-assessment the developer records before exporting.
    /// `pending` until the session is ended.
    var result: Result

    /// Free-form, redaction-safe note the developer can attach to
    /// the final artifact. Nil by default; the export never
    /// auto-populates this from event details.
    var note: String?

    enum Result: String, Sendable, Equatable, Codable {
        case pending
        case pass
        case fail
        case inconclusive
    }
}

extension PlaidValidationSession {

    /// Starts a fresh session. `now` injectable for deterministic tests.
    init(
        startedAt now: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.startedAt = now
        self.endedAt = nil
        self.events = []
        self.result = .pending
        self.note = nil
    }

    /// Whether the session has been finalized (ended + result set).
    var isFinalized: Bool {
        endedAt != nil && result != .pending
    }

    /// Derived duration. `nil` until the session is ended.
    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Event

/// A single redacted event in the session. Events are append-only.
struct PlaidValidationEvent: Sendable, Equatable, Codable, Identifiable {

    let id: UUID
    let timestamp: Date
    let kind: Kind
    let details: [String: String]

    /// The narrow set of events the recorder accepts. Adding a new
    /// case requires bumping `PlaidValidationSession.schemaVersion`.
    enum Kind: String, Sendable, Equatable, Codable {
        case sessionStarted = "session_started"
        case brokerConfigSaved = "broker_config_saved"
        case brokerConfigCleared = "broker_config_cleared"
        case brokerHealthChecked = "broker_health_checked"
        case linkLaunchRequested = "link_launch_requested"
        case linkPhaseChanged = "link_phase_changed"
        case universalLinkObserved = "universal_link_observed"
        case publicTokenExchanged = "public_token_exchanged"
        case itemHandlePersisted = "item_handle_persisted"
        case itemHandleCleared = "item_handle_cleared"
        case syncStarted = "sync_started"
        case syncFinished = "sync_finished"
        case reconciliationFinished = "reconciliation_finished"
        case institutionObserved = "institution_observed"
        case resultMarked = "result_marked"
        case sessionEnded = "session_ended"
        case note = "note"
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        kind: Kind,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.details = details
    }
}

// MARK: - Export envelope

/// What the recorder hands back to the view when the developer taps
/// an export button. Always paired with its own schema version so a
/// later contributor can distinguish older exports.
struct PlaidValidationExport: Sendable, Equatable, Codable {

    let schemaVersion: Int
    let generatedAt: Date
    let appVersion: String
    let session: PlaidValidationSession

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case appVersion = "app_version"
        case session
    }

    init(
        session: PlaidValidationSession,
        generatedAt: Date = .now,
        appVersion: String
    ) {
        self.schemaVersion = PlaidValidationSession.schemaVersion
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.session = session
    }
}

#endif
