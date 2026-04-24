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

    /// Projects an event log into a six-bullet criterion-5 summary.
    /// Claude can scan this section alone to decide pass/fail when
    /// the full event log is too verbose.
    static func criterion5Summary(for session: PlaidValidationSession) -> [String] {
        func contains(_ kinds: PlaidValidationEvent.Kind...) -> Bool {
            session.events.contains(where: { kinds.contains($0.kind) })
        }
        func lastDetail(_ kind: PlaidValidationEvent.Kind, _ key: String) -> String? {
            session.events.last { $0.kind == kind }?.details[key]
        }

        let brokerReachable = lastDetail(.brokerHealthChecked, "reachable") == "true"
        let linkLaunched = contains(.linkLaunchRequested)
        let universalLinkObserved = contains(.universalLinkObserved)
        let exchangeSucceeded = lastDetail(.publicTokenExchanged, "success") == "true"
        let itemPersisted = contains(.itemHandlePersisted)
        let reconCreated = lastDetail(.reconciliationFinished, "created_accounts") ?? "0"
        let reconInserted = lastDetail(.reconciliationFinished, "inserted_transactions") ?? "0"
        let institution = lastDetail(.institutionObserved, "display_name")

        var lines: [String] = []
        lines.append("Broker reachable: \(brokerReachable ? "yes" : "no")")
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
}

#endif
