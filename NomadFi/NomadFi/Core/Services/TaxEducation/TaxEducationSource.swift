// TaxEducationSource.swift
// NomadFi
//
// A single official-source citation for a tax education lesson.
// Every source the catalogue exposes is listed in docs/README.md
// under the "Tax and Residency" and jurisdiction-specific sections
// so the app never fetches, caches, or re-publishes the linked
// content. A lesson without at least one source is considered
// invalid and excluded by `TaxEducationCatalog` — see the focused
// tests.

import Foundation

/// A named official-source link surfaced on a lesson detail view.
struct TaxEducationSource: Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let publisher: String
    let title: String
    let url: URL

    /// One-sentence description of why the source backs this
    /// lesson. Kept short so the detail view stays scannable.
    let summary: String
}
