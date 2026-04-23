// TaxEducationRegionProgressSummary.swift
// NomadFi
//
// Per-region progress rollup. Derived from the catalogue bundle +
// persisted `TaxEducationProgressRecord`s by
// `TaxEducationProgressService.summary(for:in:)`.
//
// Never implies tax or compliance completion — progress here is
// about whether the user *reviewed* the education content NomadFi
// carries, not whether their return is done.

import Foundation

struct TaxEducationRegionProgressSummary: Sendable, Equatable {

    let region: TaxEducationRegion

    /// Number of lessons the user has marked reviewed.
    let lessonsReviewed: Int

    /// Total number of lessons the catalogue exposes for this
    /// region (already validated by `TaxEducationCatalog.isValid`).
    let lessonsTotal: Int

    /// Checklist items the user has toggled completed.
    let checklistItemsCompleted: Int

    /// Total items on the region's starter checklist.
    let checklistItemsTotal: Int

    // MARK: - Derived

    /// Combined completed-vs-total across lessons and checklist.
    /// Feeds the section header's "X of Y steps reviewed" chip.
    var stepsReviewed: Int { lessonsReviewed + checklistItemsCompleted }
    var stepsTotal: Int { lessonsTotal + checklistItemsTotal }

    /// 0.0–1.0 — returns 0 when there are no items (avoids NaN).
    var completionFraction: Double {
        guard stepsTotal > 0 else { return 0 }
        return Double(stepsReviewed) / Double(stepsTotal)
    }

    /// 0–100. Matches `completionFraction` but pre-rounded so the
    /// UI can render without another conversion pass.
    var completionPercent: Int {
        Int((completionFraction * 100).rounded())
    }

    /// True when every lesson and every checklist item is marked
    /// completed. Never claims the user is finished with taxes —
    /// only that they reviewed NomadFi's education content.
    var isReviewed: Bool {
        stepsTotal > 0 && stepsReviewed == stepsTotal
    }

    /// Short, calm caption used in the region header.
    var displayCaption: String {
        guard stepsTotal > 0 else { return "No lessons or checklist items yet." }
        if isReviewed {
            return "All \(stepsTotal) steps reviewed for this jurisdiction."
        }
        return "\(stepsReviewed) of \(stepsTotal) steps reviewed."
    }
}
