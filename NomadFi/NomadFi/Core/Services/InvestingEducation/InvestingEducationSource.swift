// InvestingEducationSource.swift
// NomadFi
//
// A single official-source citation for an investing-education
// lesson. Every source surfaced is published by a regulator, an
// investor-protection body, or a tax authority — never a fund
// company, brokerage, blog, or SEO finance page. Lessons with an
// empty `sources` array are rejected by `InvestingEducationCatalog`
// validation and excluded from the UI.

import Foundation

/// Named official-source link shown on a lesson detail view.
struct InvestingEducationSource: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier — keeps the publisher prefix so duplicate
    /// titles across regulators don't collide.
    let id: String

    /// Publishing body (e.g. "Investor.gov / SEC", "CIRO", "CIPF",
    /// "CRA", "IRS"). The UI displays this verbatim so users see
    /// which authority backs the lesson.
    let publisher: String

    let title: String

    let url: URL

    /// One-sentence description of why the source backs this
    /// lesson. Kept short so the detail view stays scannable.
    let summary: String
}
