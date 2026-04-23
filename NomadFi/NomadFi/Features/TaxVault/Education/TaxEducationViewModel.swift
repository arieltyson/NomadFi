// TaxEducationViewModel.swift
// NomadFi
//
// Observable wrapper around `TaxEducationSelector` and
// `TaxEducationProgressService`. The Tax Vault view passes in the
// current `@Query` results for jurisdictions and progress records;
// this VM orchestrates refresh + explicit write actions. Reads
// are delegated to the pure service so child views can render
// directly from the records without re-querying.

import Foundation
import SwiftData
import SwiftUI

/// Observable state holder for the Tax Vault education surface.
@MainActor
@Observable
final class TaxEducationViewModel {

    // MARK: - State

    /// Region bundles in the order the selector picked them —
    /// home first, then other active jurisdictions.
    var regionBundles: [TaxEducationRegionBundle] = []

    /// Lesson currently open in the detail sheet. The sheet
    /// presentation binds to `selection != nil`.
    var selection: TaxEducationLesson?

    // MARK: - Refresh

    /// Rebuilds `regionBundles` from the user's active
    /// jurisdictions. Called from the Tax Vault view's
    /// `.task(id:)` so it re-runs when the query changes.
    func refresh(from jurisdictions: [JurisdictionProfile]) {
        regionBundles = TaxEducationSelector.regionBundles(for: jurisdictions)
    }

    // MARK: - Selection

    func select(_ lesson: TaxEducationLesson) {
        selection = lesson
    }

    func clearSelection() {
        selection = nil
    }

    // MARK: - Progress reads

    /// Per-region progress summary for the region's bundle.
    func summary(
        for bundle: TaxEducationRegionBundle,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationRegionProgressSummary {
        TaxEducationProgressService.summary(for: bundle, in: records)
    }

    /// Next recommended step for the bundle, or `nil` when the
    /// region is fully reviewed.
    func nextStep(
        for bundle: TaxEducationRegionBundle,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationNextStep? {
        TaxEducationProgressService.nextStep(for: bundle, in: records)
    }

    /// Whether a specific lesson has been explicitly reviewed.
    func isLessonReviewed(
        _ lesson: TaxEducationLesson,
        in records: [TaxEducationProgressRecord]
    ) -> Bool {
        TaxEducationProgressService.status(
            forLessonID: lesson.id,
            region: lesson.region,
            in: records
        ) == .completed
    }

    /// Whether a specific checklist item is completed.
    func isChecklistItemCompleted(
        _ item: TaxEducationChecklistItem,
        region: TaxEducationRegion,
        in records: [TaxEducationProgressRecord]
    ) -> Bool {
        TaxEducationProgressService.status(
            forChecklistItemID: item.id,
            region: region,
            in: records
        ) == .completed
    }

    // MARK: - Progress writes (explicit user actions)

    /// Marks a lesson reviewed. Called from the "Mark reviewed"
    /// button on the lesson detail sheet.
    func markLessonReviewed(
        _ lesson: TaxEducationLesson,
        in modelContext: ModelContext,
        records: [TaxEducationProgressRecord],
        now: Date = .now
    ) {
        TaxEducationProgressService.markLessonReviewed(
            lesson,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    /// Reverses a previous "Mark reviewed" action.
    func unmarkLessonReviewed(
        _ lesson: TaxEducationLesson,
        in modelContext: ModelContext,
        records: [TaxEducationProgressRecord],
        now: Date = .now
    ) {
        TaxEducationProgressService.unmarkLessonReviewed(
            lesson,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    /// Flips a checklist item between completed and not-started.
    func toggleChecklistItem(
        _ item: TaxEducationChecklistItem,
        region: TaxEducationRegion,
        in modelContext: ModelContext,
        records: [TaxEducationProgressRecord],
        now: Date = .now
    ) {
        TaxEducationProgressService.toggleChecklistItem(
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
