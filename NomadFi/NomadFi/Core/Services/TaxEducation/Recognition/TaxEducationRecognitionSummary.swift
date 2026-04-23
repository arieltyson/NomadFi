// TaxEducationRecognitionSummary.swift
// NomadFi
//
// Portfolio-wide recognition output. Pure value — the computer
// derives this per refresh from the existing progression records.
// Shipping no new persistence is explicit: if the user regresses
// progress, the relevant badges drop off on the next refresh.

import Foundation

struct TaxEducationRecognitionSummary: Sendable, Equatable {

    /// Badges that span the whole Tax Vault (e.g. first-step, or
    /// the multi-region badge). Rendered as a compact strip at
    /// the top of the Learn surface.
    let portfolioBadges: [TaxEducationRecognitionBadge]

    /// Region-scoped badges keyed by region, in selector order.
    /// Rendered as chips inside each region block so the user can
    /// see what they've earned for each jurisdiction at a glance.
    let badgesByRegion: [TaxEducationRegion: [TaxEducationRecognitionBadge]]

    /// Count across all badges — useful for accessibility copy.
    var totalCount: Int {
        portfolioBadges.count + badgesByRegion.values.reduce(0) { $0 + $1.count }
    }

    /// `true` when no recognition has been earned yet. The Learn
    /// surface hides the strip entirely in this state rather than
    /// rendering an empty placeholder.
    var isEmpty: Bool {
        totalCount == 0
    }
}
