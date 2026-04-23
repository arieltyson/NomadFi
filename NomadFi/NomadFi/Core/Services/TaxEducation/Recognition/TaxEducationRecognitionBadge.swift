// TaxEducationRecognitionBadge.swift
// NomadFi
//
// A single recognition row surfaced on the Tax Vault Learn
// surface. Pure value — built by the computer per refresh, never
// persisted. Titles are declarative and calm; accessibility
// labels spell out the recognition without implying compliance.

import Foundation

struct TaxEducationRecognitionBadge: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier — derived from `kind` so SwiftUI can diff
    /// rows across refreshes.
    let id: String

    let kind: TaxEducationRecognitionKind

    /// `nil` when the badge is portfolio-wide (e.g.
    /// `.firstStepReviewed`, `.multiRegionReviewed`). Otherwise
    /// the region the badge belongs to.
    let region: TaxEducationRegion?

    /// Short title shown in the UI. Never implies filing is done.
    let title: String

    /// One-line explanation of what the badge recognises.
    let subtitle: String

    /// SF Symbol paired with the title so Differentiate-Without-
    /// Color users read the badge correctly.
    let systemImage: String

    /// VoiceOver phrasing — concatenated from title + subtitle +
    /// an explicit "education only" reminder.
    let accessibilityLabel: String
}
