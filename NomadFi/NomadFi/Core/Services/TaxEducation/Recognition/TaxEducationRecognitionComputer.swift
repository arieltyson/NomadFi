// TaxEducationRecognitionComputer.swift
// NomadFi
//
// Pure derived recognition for the Tax Vault Learn surface. No
// persistence, no timers, no points, no levels. The same input
// (`[TaxEducationRegionBundle]` + `[TaxEducationProgressRecord]`)
// deterministically yields the same `TaxEducationRecognitionSummary`.
//
// Rules pinned in `TaxEducationRecognitionComputerTests`:
//
//   • `.firstStepReviewed` appears as soon as any lesson is marked
//     reviewed, any checklist item is toggled completed, or any
//     quiz has been attempted (pass or fail).
//   • `.starterReviewed(region)` appears when every lesson *and*
//     every checklist item for the region is completed — the quiz
//     is not required.
//   • `.knowledgeCheckPassed(region)` appears only when the
//     region's quiz status is `.completed`.
//   • `.regionReviewed(region)` uses
//     `TaxEducationRegionProgressSummary.isReviewed`, which
//     requires the quiz to pass when the region ships one.
//   • `.multiRegionReviewed` appears when two or more regions
//     satisfy `.regionReviewed`.
//   • Unmarking / failing a quiz drops the corresponding badges on
//     the next refresh — current-state only.
//   • No banned vocabulary in any badge copy.

import Foundation

enum TaxEducationRecognitionComputer {

    // MARK: - Public API

    /// Builds the summary from the selector's region bundles and
    /// the live progress records. Safe for empty inputs.
    @MainActor
    static func summary(
        for bundles: [TaxEducationRegionBundle],
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationRecognitionSummary {
        guard !bundles.isEmpty else {
            return TaxEducationRecognitionSummary(
                portfolioBadges: [],
                badgesByRegion: [:]
            )
        }

        // Compute per-region summaries once — reused by every rule.
        let regionSummaries = bundles.map { bundle in
            (bundle: bundle,
             summary: TaxEducationProgressService.summary(for: bundle, in: records))
        }

        var portfolio: [TaxEducationRecognitionBadge] = []
        if hasAnyExplicitCompletion(in: records) {
            portfolio.append(firstStepBadge)
        }
        let fullyReviewedRegions = regionSummaries
            .filter { $0.summary.isReviewed }
            .map(\.bundle.region)
        if fullyReviewedRegions.count >= 2 {
            portfolio.append(multiRegionBadge(regions: fullyReviewedRegions))
        }

        var byRegion: [TaxEducationRegion: [TaxEducationRecognitionBadge]] = [:]
        for (bundle, regionSummary) in regionSummaries {
            var badges: [TaxEducationRecognitionBadge] = []
            if regionSummary.hasCompletedLessonsAndChecklist {
                badges.append(starterBadge(for: bundle.region))
            }
            if regionSummary.quizPassed {
                badges.append(knowledgeCheckBadge(for: bundle.region))
            }
            if regionSummary.isReviewed {
                badges.append(regionReviewedBadge(for: bundle.region))
            }
            if !badges.isEmpty {
                byRegion[bundle.region] = badges
            }
        }

        return TaxEducationRecognitionSummary(
            portfolioBadges: portfolio,
            badgesByRegion: byRegion
        )
    }

    // MARK: - "First step reviewed" detection

    /// Any persisted completion flag counts — whether or not the
    /// catalogue still references the underlying lesson / item /
    /// quiz, we're asking "did the user explicitly do something?".
    private static func hasAnyExplicitCompletion(
        in records: [TaxEducationProgressRecord]
    ) -> Bool {
        records.contains { record in
            switch record.kind {
            case .lesson, .checklistItem:
                return record.status == .completed
            case .quiz:
                // A quiz attempt — pass or fail — counts as an
                // explicit step, since the user actively submitted.
                return record.lastInteractedAt != nil
                    && (record.quizScorePercent != nil
                        || record.status != .notStarted)
            }
        }
    }

    // MARK: - Badge builders

    private static let firstStepBadge = TaxEducationRecognitionBadge(
        id: "first-step-reviewed",
        kind: .firstStepReviewed,
        region: nil,
        title: "First step reviewed",
        subtitle: "You've started reviewing NomadFi's education content.",
        systemImage: "sparkles",
        accessibilityLabel: "Recognition. First step reviewed. You've started reviewing NomadFi's education content. Education only."
    )

    private static func starterBadge(
        for region: TaxEducationRegion
    ) -> TaxEducationRecognitionBadge {
        TaxEducationRecognitionBadge(
            id: "starter-reviewed-\(region.rawValue)",
            kind: .starterReviewed(region),
            region: region,
            title: "\(region.displayName) starter reviewed",
            subtitle: "Every lesson and checklist item for this jurisdiction is marked reviewed.",
            systemImage: "book.closed",
            accessibilityLabel: "Recognition. \(region.displayName) starter reviewed. Every lesson and checklist item for this jurisdiction is marked reviewed. Education only."
        )
    }

    private static func knowledgeCheckBadge(
        for region: TaxEducationRegion
    ) -> TaxEducationRecognitionBadge {
        TaxEducationRecognitionBadge(
            id: "knowledge-check-passed-\(region.rawValue)",
            kind: .knowledgeCheckPassed(region),
            region: region,
            title: "\(region.displayName) knowledge check passed",
            subtitle: "You passed this jurisdiction's knowledge check.",
            systemImage: "checkmark.seal",
            accessibilityLabel: "Recognition. \(region.displayName) knowledge check passed. You passed this jurisdiction's knowledge check. Education only."
        )
    }

    private static func regionReviewedBadge(
        for region: TaxEducationRegion
    ) -> TaxEducationRecognitionBadge {
        TaxEducationRecognitionBadge(
            id: "region-reviewed-\(region.rawValue)",
            kind: .regionReviewed(region),
            region: region,
            title: "\(region.displayName) reviewed",
            subtitle: "Every step for this jurisdiction is marked reviewed.",
            systemImage: "checkmark.circle",
            accessibilityLabel: "Recognition. \(region.displayName) reviewed. Every step for this jurisdiction is marked reviewed. Education only."
        )
    }

    private static func multiRegionBadge(
        regions: [TaxEducationRegion]
    ) -> TaxEducationRecognitionBadge {
        let count = regions.count
        return TaxEducationRecognitionBadge(
            id: "multi-region-reviewed",
            kind: .multiRegionReviewed,
            region: nil,
            title: "Multi-region reviewed",
            subtitle: "You've fully reviewed \(count) jurisdictions.",
            systemImage: "globe",
            accessibilityLabel: "Recognition. Multi-region reviewed. You have fully reviewed \(count) jurisdictions. Education only."
        )
    }
}
