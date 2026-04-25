// InvestingEducationRegionProgressSummary.swift
// NomadFi
//
// Roll-up of one region's investing-education progress. Pure value
// type built by `InvestingEducationProgressService.summary(...)`.

import Foundation

struct InvestingEducationRegionProgressSummary: Sendable, Equatable, Identifiable {

    var id: String { region.rawValue }

    let region: InvestingEducationRegion

    let lessonsReviewed: Int
    let lessonsTotal: Int

    let checklistItemsCompleted: Int
    let checklistItemsTotal: Int

    /// Convenience for chips and progress copy. Sums lesson + item
    /// completion so a single number renders next to the region
    /// name without the UI doing arithmetic.
    var totalCompleted: Int {
        lessonsReviewed + checklistItemsCompleted
    }

    var totalTrackable: Int {
        lessonsTotal + checklistItemsTotal
    }

    /// True when every lesson and every checklist item is complete.
    var hasCompletedLessonsAndChecklist: Bool {
        lessonsTotal > 0
            && checklistItemsTotal > 0
            && lessonsReviewed == lessonsTotal
            && checklistItemsCompleted == checklistItemsTotal
    }
}
