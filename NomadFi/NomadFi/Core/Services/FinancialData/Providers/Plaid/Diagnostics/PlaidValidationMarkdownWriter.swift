// PlaidValidationMarkdownWriter.swift
// NomadFi
//
// Converts a ``PlaidValidationExport`` into the Markdown shape
// documented at `docs/research/PlaidValidationEvidenceTemplate.md`.
// Kept separate from the recorder so the serializer can be unit-
// tested without building a recorder, and so a future schema bump
// only needs to touch one file.

#if DEBUG

import Foundation

enum PlaidValidationMarkdownWriter {

    /// Renders the export as Markdown. Deterministic — sorting and
    /// date formatting are stable across runs.
    static func render(_ export: PlaidValidationExport) -> String {
        let session = export.session
        let timestampFormatter = ISO8601DateFormatter()
        var lines: [String] = []

        lines.append("# NomadFi Plaid Sandbox Validation Report")
        lines.append("")
        lines.append("- **Session ID:** \(session.id.uuidString)")
        lines.append("- **Started:** \(timestampFormatter.string(from: session.startedAt))")
        if let endedAt = session.endedAt {
            lines.append("- **Ended:** \(timestampFormatter.string(from: endedAt))")
        } else {
            lines.append("- **Ended:** _pending_")
        }
        if let duration = session.duration {
            lines.append("- **Duration:** \(formatDuration(duration))")
        }
        lines.append("- **Result:** \(session.result.rawValue)")
        if let note = session.note, !note.isEmpty {
            lines.append("- **Note:** \(note)")
        }
        lines.append("- **App version:** \(export.appVersion)")
        lines.append("- **Schema version:** \(export.schemaVersion)")
        lines.append("")

        lines.append("## Events")
        lines.append("")
        if session.events.isEmpty {
            lines.append("_No events recorded._")
        } else {
            lines.append("| # | Time | Event | Details |")
            lines.append("|---|------|-------|---------|")
            for (index, event) in session.events.enumerated() {
                let time = timestampFormatter.string(from: event.timestamp)
                let kind = event.kind.rawValue
                let details = renderDetails(event.details)
                lines.append("| \(index + 1) | \(time) | \(kind) | \(details) |")
            }
        }
        lines.append("")

        lines.append("## Criterion 5 self-assessment")
        lines.append("")
        let assessment = criterion5Summary(for: session)
        for line in assessment {
            lines.append("- \(line)")
        }
        lines.append("")

        lines.append("> Generated at \(timestampFormatter.string(from: export.generatedAt))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Deterministically formats the `details` dictionary into a
    /// single cell value. Sort by key so diffs stay clean across
    /// runs with the same event shape.
    static func renderDetails(_ details: [String: String]) -> String {
        guard !details.isEmpty else { return "—" }
        return details
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\(escapeDetailValue($0.value))" }
            .joined(separator: ", ")
    }

    static func escapeDetailValue(_ raw: String) -> String {
        // Markdown tables choke on unescaped pipes and newlines.
        raw.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let remainder = total % 60
        if minutes == 0 {
            return "\(remainder)s"
        }
        return "\(minutes)m \(remainder)s"
    }

    /// Projects an event log into a seven-bullet criterion-5 summary.
    /// Claude can scan this section alone to decide pass/fail when
    /// the full event log is too verbose.
    ///
    /// Broker reachability is reported as **inferred** when the
    /// session has no explicit `broker_health_checked` event but
    /// downstream calls (public-token exchange, `/transactions/sync`)
    /// succeeded — those calls *are* the broker proving it is
    /// reachable. The earlier writer reported "no" in that case,
    /// which created a false-negative on the April 2026 sandbox run.
    static func criterion5Summary(for session: PlaidValidationSession) -> [String] {
        func contains(_ kinds: PlaidValidationEvent.Kind...) -> Bool {
            session.events.contains(where: { kinds.contains($0.kind) })
        }
        func lastDetail(_ kind: PlaidValidationEvent.Kind, _ key: String) -> String? {
            session.events.last { $0.kind == kind }?.details[key]
        }

        let healthVerified = lastDetail(.brokerHealthChecked, "reachable") == "true"
        let exchangeSucceeded = lastDetail(.publicTokenExchanged, "success") == "true"
        let syncSucceeded = contains(.syncFinished)
        let linkLaunched = contains(.linkLaunchRequested)
        let universalLinkObserved = contains(.universalLinkObserved)
        let itemPersisted = contains(.itemHandlePersisted)
        let reconCreated = lastDetail(.reconciliationFinished, "created_accounts") ?? "0"
        let reconInserted = lastDetail(.reconciliationFinished, "inserted_transactions") ?? "0"
        let institution = lastDetail(.institutionObserved, "display_name")

        var lines: [String] = []
        lines.append("Broker reachable: \(brokerReachableLabel(healthVerified: healthVerified, exchangeSucceeded: exchangeSucceeded, syncSucceeded: syncSucceeded))")
        lines.append("Plaid Link launched: \(linkLaunched ? "yes" : "no")")
        lines.append("Universal-link return observed: \(universalLinkObserved ? "yes" : "no")")
        lines.append("Public-token exchanged: \(exchangeSucceeded ? "yes" : "no")")
        lines.append("Item handle persisted: \(itemPersisted ? "yes" : "no")")
        lines.append(
            "Reconciliation counts: \(reconCreated) created, \(reconInserted) inserted transactions"
        )
        if let institution, !institution.isEmpty {
            lines.append("Institution observed: \(institution) (vendor-reported by Plaid Link)")
        } else {
            lines.append("Institution observed: not recorded in this export")
        }
        lines.append("Result: \(session.result.rawValue)")
        return lines
    }

    /// Resolves the broker-reachability cell of the criterion-5
    /// summary. Distinguishes a session that explicitly probed
    /// `/health` from one that didn't but proved reachability via
    /// downstream calls. Either way, future readers see one
    /// unambiguous answer with a parenthetical describing the
    /// evidence path.
    static func brokerReachableLabel(
        healthVerified: Bool,
        exchangeSucceeded: Bool,
        syncSucceeded: Bool
    ) -> String {
        if healthVerified {
            return "yes (verified by health check)"
        }
        if exchangeSucceeded || syncSucceeded {
            return "yes (inferred from successful exchange/sync)"
        }
        return "no"
    }
}

#endif
