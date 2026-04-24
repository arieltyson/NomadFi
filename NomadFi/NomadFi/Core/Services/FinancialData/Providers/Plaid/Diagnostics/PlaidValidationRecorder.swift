// PlaidValidationRecorder.swift
// NomadFi
//
// `@MainActor @Observable` recorder the DEBUG-only developer harness
// and the Financial Connections page write into during a Phase 5D
// real-device validation run. Single instance is owned by the app
// root and injected via the SwiftUI environment; shared between
// pages so no event is lost when the user navigates between the
// harness and the main connections page.
//
// The recorder is idempotent: every public `record…` method is a
// no-op when no session is active, so call sites can hook
// defensively without branching.

#if DEBUG

import Foundation

@MainActor
@Observable
final class PlaidValidationRecorder {

    // MARK: - State

    /// Current in-flight session. Nil between sessions.
    private(set) var currentSession: PlaidValidationSession?

    /// Total sessions finalized since the recorder was constructed.
    /// Surfaced in the UI so a developer can tell whether a sync
    /// they performed was recorded into a session or thrown away.
    private(set) var finalizedSessionCount: Int = 0

    /// Last finalized session, retained so the dev harness can
    /// export it after the developer taps `End session`.
    private(set) var lastFinalizedSession: PlaidValidationSession?

    /// Whether the user has opted into including the institution
    /// display name in the exported artifact for this session.
    /// Default `false` for safety.
    var includesInstitutionName: Bool = false

    // MARK: - Dependencies

    private let clock: @Sendable () -> Date
    private let appVersion: String

    init(
        clock: @escaping @Sendable () -> Date = Date.init,
        appVersion: String? = nil
    ) {
        self.clock = clock
        self.appVersion = appVersion ?? PlaidValidationRecorder.resolveAppVersion()
    }

    // MARK: - Session lifecycle

    /// Starts a new session. If one is already in flight, it is
    /// discarded — the harness UI always shows a "Start new session"
    /// confirmation so this path is explicit.
    func startSession() {
        var session = PlaidValidationSession(startedAt: clock())
        session.events.append(
            PlaidValidationEvent(
                timestamp: session.startedAt,
                kind: .sessionStarted,
                details: ["schema_version": "\(PlaidValidationSession.schemaVersion)"]
            )
        )
        currentSession = session
    }

    /// Finalizes the current session. Does nothing if none is active.
    func endSession(
        result: PlaidValidationSession.Result,
        note: String? = nil
    ) {
        guard var session = currentSession else { return }
        let endedAt = clock()
        session.endedAt = endedAt
        session.result = result
        session.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        var details: [String: String] = ["result": result.rawValue]
        if let note, !note.isEmpty {
            details["note_length"] = "\(note.count)"
        }
        session.events.append(
            PlaidValidationEvent(
                timestamp: endedAt,
                kind: .sessionEnded,
                details: details
            )
        )

        currentSession = nil
        lastFinalizedSession = session
        finalizedSessionCount += 1
    }

    /// Clears the last finalized session so the UI can return to a
    /// clean state after the developer exports it.
    func clearLastFinalizedSession() {
        lastFinalizedSession = nil
    }

    // MARK: - Event recording

    func recordBrokerConfigSaved(
        brokerURL: URL?,
        hasSecret: Bool
    ) {
        appendEvent(
            kind: .brokerConfigSaved,
            details: [
                "broker_url": PlaidValidationRedactor.brokerURLPresence(from: brokerURL),
                "broker_secret_configured": "\(hasSecret)",
            ]
        )
    }

    func recordBrokerConfigCleared() {
        appendEvent(kind: .brokerConfigCleared)
    }

    func recordBrokerHealthChecked(
        reachable: Bool,
        env: String? = nil,
        requiresSecret: Bool? = nil,
        redirectConfigured: Bool? = nil,
        failureReason: String? = nil
    ) {
        var details: [String: String] = ["reachable": "\(reachable)"]
        if let env { details["env"] = env }
        if let requiresSecret { details["requires_secret"] = "\(requiresSecret)" }
        if let redirectConfigured { details["redirect_uri_configured"] = "\(redirectConfigured)" }
        if !reachable {
            details["failure_reason"] = PlaidValidationRedactor.redactedError(failureReason)
        }
        appendEvent(kind: .brokerHealthChecked, details: details)
    }

    func recordLinkLaunchRequested() {
        appendEvent(kind: .linkLaunchRequested)
    }

    func recordLinkPhaseChanged(from previous: String, to current: String) {
        appendEvent(
            kind: .linkPhaseChanged,
            details: ["from": previous, "to": current]
        )
    }

    func recordUniversalLinkObserved(host: String? = nil) {
        // We log only the host (which is NomadFi's own GitHub Pages
        // origin) and never the query string — OAuth state values
        // can carry correlation identifiers Plaid uses on its side.
        var details: [String: String] = [:]
        if let host { details["host"] = host }
        appendEvent(kind: .universalLinkObserved, details: details)
    }

    func recordPublicTokenExchanged(
        success: Bool,
        failureReason: String? = nil
    ) {
        var details: [String: String] = ["success": "\(success)"]
        if !success {
            details["failure_reason"] = PlaidValidationRedactor.redactedError(failureReason)
        }
        appendEvent(kind: .publicTokenExchanged, details: details)
    }

    func recordItemHandlePersisted(rawHandle: String) {
        let masked = PlaidValidationRedactor.maskedItemHandle(rawHandle) ?? "unknown"
        appendEvent(
            kind: .itemHandlePersisted,
            details: ["masked_item_handle": masked]
        )
    }

    func recordItemHandleCleared() {
        appendEvent(kind: .itemHandleCleared)
    }

    func recordInstitutionObserved(displayName: String?) {
        guard let resolved = PlaidValidationRedactor.institutionName(
            displayName,
            include: includesInstitutionName
        ) else {
            // Still record that one was observed — just without the name.
            appendEvent(
                kind: .institutionObserved,
                details: ["display_name_included": "false"]
            )
            return
        }
        appendEvent(
            kind: .institutionObserved,
            details: [
                "display_name_included": "true",
                "display_name": resolved,
            ]
        )
    }

    func recordSyncStarted(windowStart: Date, windowEnd: Date) {
        let formatter = ISO8601DateFormatter()
        appendEvent(
            kind: .syncStarted,
            details: [
                "window_start": formatter.string(from: windowStart),
                "window_end": formatter.string(from: windowEnd),
            ]
        )
    }

    func recordSyncFinished(report: FinancialDataSyncReport) {
        var details: [String: String] = [
            "account_snapshots": "\(report.accountSnapshots.count)",
            "transaction_snapshots": "\(report.transactionSnapshots.count)",
            "degraded_gracefully": "\(report.degradedGracefully)",
        ]
        for outcome in report.outcomes {
            details["provider_\(outcome.providerKind.logKey)"] = outcome.result.logLabel
        }
        appendEvent(kind: .syncFinished, details: details)
    }

    func recordReconciliationFinished(result: FinancialDataReconciliationResult) {
        appendEvent(
            kind: .reconciliationFinished,
            details: [
                "matched_durable": "\(result.matchedAccountsByDurableLink)",
                "matched_fallback": "\(result.matchedAccountsByFallback)",
                "created_accounts": "\(result.createdAccounts)",
                "updated_accounts": "\(result.updatedAccounts)",
                "inserted_transactions": "\(result.insertedTransactions)",
                "skipped_duplicate_transactions": "\(result.skippedDuplicateTransactions)",
                "unresolved_ambiguous_snapshots": "\(result.unresolvedAmbiguousSnapshots)",
            ]
        )
    }

    func recordResultMarked(_ result: PlaidValidationSession.Result) {
        appendEvent(
            kind: .resultMarked,
            details: ["result": result.rawValue]
        )
    }

    func recordNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendEvent(
            kind: .note,
            details: [
                "length": "\(trimmed.count)",
                "preview": String(trimmed.prefix(140)),
            ]
        )
    }

    // MARK: - Export

    /// Returns the last finalized session wrapped in an export
    /// envelope. Nil if no session has been finalized yet.
    func export() -> PlaidValidationExport? {
        guard let session = lastFinalizedSession else { return nil }
        return PlaidValidationExport(
            session: session,
            generatedAt: clock(),
            appVersion: appVersion
        )
    }

    /// Serializes the last finalized export to JSON. UTF-8 bytes,
    /// `sortedKeys` + `prettyPrinted` so diffing across runs is
    /// cheap, ISO-8601 timestamps so Claude can parse them.
    func exportJSON() throws -> Data? {
        guard let export = export() else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    /// Serializes the last finalized export to the Markdown shape
    /// documented in `docs/research/PlaidValidationEvidenceTemplate.md`.
    func exportMarkdown() -> String? {
        guard let export = export() else { return nil }
        return PlaidValidationMarkdownWriter.render(export)
    }

    // MARK: - Private

    private func appendEvent(
        kind: PlaidValidationEvent.Kind,
        details: [String: String] = [:]
    ) {
        guard currentSession != nil else { return }
        let event = PlaidValidationEvent(
            timestamp: clock(),
            kind: kind,
            details: details
        )
        currentSession?.events.append(event)
    }

    /// Reads the app's CFBundleShortVersionString + CFBundleVersion
    /// so exports carry the build they were produced from. Falls
    /// back to "dev" for test hosts without an Info.plist.
    nonisolated private static func resolveAppVersion() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

#endif
