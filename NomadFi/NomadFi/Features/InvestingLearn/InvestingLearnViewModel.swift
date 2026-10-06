// InvestingLearnViewModel.swift
// NomadFi
//
// Observable wrapper around `InvestingEducationSelector` and
// `InvestingEducationProgressService`. Mirrors the shape of
// `TaxEducationViewModel` so the two surfaces stay structurally
// uniform without sharing state. The view passes in current
// `@Query` results for jurisdictions and progress records; this VM
// orchestrates refresh + explicit write actions. Reads delegate to
// the pure service so child views render straight from the records.

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class InvestingLearnViewModel {

    // MARK: - State

    /// Region bundles in the order the selector picked them —
    /// home first, then other active jurisdictions.
    var regionBundles: [InvestingEducationRegionBundle] = []

    /// Lesson currently open in the detail sheet. The sheet
    /// presentation binds to `selection != nil`.
    var selection: InvestingEducationLesson?

    // MARK: - Refresh

    /// Rebuilds `regionBundles` from the user's active
    /// jurisdictions. Called from the view's `.task(id:)` so it
    /// re-runs when the underlying query changes.
    func refresh(from jurisdictions: [JurisdictionProfile]) {
        regionBundles = InvestingEducationSelector.regionBundles(for: jurisdictions)
    }

    /// The bundle for `region`, if it is one of the person's
    /// jurisdictions — the content behind a region's card.
    func bundle(for region: InvestingEducationRegion) -> InvestingEducationRegionBundle? {
        regionBundles.first { $0.region == region }
    }

    // MARK: - Selection

    func select(_ lesson: InvestingEducationLesson) {
        selection = lesson
    }

    func clearSelection() {
        selection = nil
    }

    // MARK: - Progress reads

    func summary(
        for bundle: InvestingEducationRegionBundle,
        in records: [InvestingEducationProgressRecord]
    ) -> InvestingEducationRegionProgressSummary {
        InvestingEducationProgressService.summary(for: bundle, in: records)
    }

    func nextStep(
        for bundle: InvestingEducationRegionBundle,
        in records: [InvestingEducationProgressRecord]
    ) -> InvestingEducationNextStep? {
        InvestingEducationProgressService.nextStep(for: bundle, in: records)
    }

    func isLessonReviewed(
        _ lesson: InvestingEducationLesson,
        in records: [InvestingEducationProgressRecord]
    ) -> Bool {
        InvestingEducationProgressService.status(
            forLessonID: lesson.id,
            region: lesson.region,
            in: records
        ) == .completed
    }

    func isChecklistItemCompleted(
        _ item: InvestingEducationChecklistItem,
        region: InvestingEducationRegion,
        in records: [InvestingEducationProgressRecord]
    ) -> Bool {
        InvestingEducationProgressService.status(
            forChecklistItemID: item.id,
            region: region,
            in: records
        ) == .completed
    }

    // MARK: - Progress writes (explicit user actions)

    func markLessonReviewed(
        _ lesson: InvestingEducationLesson,
        in modelContext: ModelContext,
        records: [InvestingEducationProgressRecord],
        now: Date = .now
    ) {
        InvestingEducationProgressService.markLessonReviewed(
            lesson,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    func unmarkLessonReviewed(
        _ lesson: InvestingEducationLesson,
        in modelContext: ModelContext,
        records: [InvestingEducationProgressRecord],
        now: Date = .now
    ) {
        InvestingEducationProgressService.unmarkLessonReviewed(
            lesson,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    func toggleChecklistItem(
        _ item: InvestingEducationChecklistItem,
        region: InvestingEducationRegion,
        in modelContext: ModelContext,
        records: [InvestingEducationProgressRecord],
        now: Date = .now
    ) {
        InvestingEducationProgressService.toggleChecklistItem(
            item,
            region: region,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    // MARK: - Derived

    var hasContent: Bool {
        !regionBundles.isEmpty
    }
}
