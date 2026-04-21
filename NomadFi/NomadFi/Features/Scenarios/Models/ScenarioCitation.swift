// ScenarioCitation.swift
// NomadFi
//
// A single source record the Scenario Decision Brief cites in its
// "Sources" section. Every citation carries an evidence tag so the UI
// never conflates an official issuer page with a user-confirmed value
// or a derived inference.

import Foundation

/// A named external source the decision brief points to. Citations are
/// purely informational — the app never claims to have fetched live
/// data from the linked resource, only that the resource is where the
/// user can verify the underlying fact.
struct ScenarioCitation: Identifiable, Sendable, Equatable {

    /// Stable identifier for diffing inside `ForEach`.
    let id: String

    /// Short, user-facing title — typically the page or document name.
    let title: String

    /// The publishing entity (e.g., "Amazon", "Chase", "Wise", "myFICO").
    let publisher: String

    /// Link to the current official page. Opens in the system browser.
    let url: URL

    /// One-sentence summary of what the source is used for in the brief.
    let summary: String

    /// Evidence tier for this source as it appears in the brief —
    /// almost always `.officialSource`, but kept flexible so later
    /// scenarios can cite primary research or regulator guidance.
    let evidence: ScenarioEvidenceTag
}
