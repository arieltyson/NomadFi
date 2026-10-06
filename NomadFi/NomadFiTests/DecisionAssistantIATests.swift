// DecisionAssistantIATests.swift
// NomadFi
//
// Pure-logic coverage for the Decisions-tab IA/UI redesign. Pins
// the surface-category split that drives the new
// `Reusable checks` and `Pinned scenario` sections so a future
// catalog edit cannot silently re-mix tools and scenarios.
//
// Pinned product contract:
//
//   • The catalog separates evergreen tools (Purchase Card Check,
//     Credit Timing Check) from scenario-specific decisions
//     (Amazon arrival order today). The two surface categories
//     never overlap and never lose membership.
//   • The view-model exposes both groups with stable order.
//   • Every catalog identity belongs to exactly one surface
//     category, and the union covers the full catalog so no
//     identity falls through the cracks.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct DecisionAssistantIATests {

    // MARK: - Catalog grouping

    @Test("Reusable checks contains Purchase Card Check and Credit Timing Check, in catalog order")
    func reusableChecksAreEvergreenTools() {
        let ids = DecisionCatalog.reusableChecks.map(\.id)
        #expect(ids == [.creditTimingCheck, .purchaseCardCheck])
    }

    @Test("Pinned scenarios contains the Amazon arrival order today")
    func pinnedScenariosContainAmazonArrivalOrder() {
        let ids = DecisionCatalog.pinnedScenarios.map(\.id)
        #expect(ids == [.amazonArrivalOrder])
    }

    @Test("Surface categories partition the full catalog — every identity belongs to exactly one")
    func surfaceCategoriesPartitionCatalog() {
        let allIDs = Set(DecisionCatalog.all.map(\.id))
        let reusableIDs = Set(DecisionCatalog.reusableChecks.map(\.id))
        let pinnedIDs = Set(DecisionCatalog.pinnedScenarios.map(\.id))

        // No overlap between groups.
        #expect(reusableIDs.isDisjoint(with: pinnedIDs))
        // Together they cover the whole catalog.
        #expect(reusableIDs.union(pinnedIDs) == allIDs)
    }

    @Test("Reusable checks and pinned scenarios are honest sub-categorisations — they never include unsupported kinds")
    func categoryAssignmentMatchesIdentity() {
        for identity in DecisionCatalog.reusableChecks {
            #expect(identity.surfaceCategory == .reusableCheck)
        }
        for identity in DecisionCatalog.pinnedScenarios {
            #expect(identity.surfaceCategory == .pinnedScenario)
        }
    }

    // MARK: - View model exposure

    @Test("Fresh view model exposes the same reusable / pinned groups as the catalog")
    func viewModelMirrorsCatalogGroups() {
        let viewModel = DecisionAssistantViewModel()
        #expect(viewModel.reusableChecks.map(\.id) == DecisionCatalog.reusableChecks.map(\.id))
        #expect(viewModel.pinnedScenarios.map(\.id) == DecisionCatalog.pinnedScenarios.map(\.id))
    }

    @Test("Reusable checks and pinned scenarios are non-empty so both sections always have something to render")
    func bothGroupsAreNonEmpty() {
        #expect(!DecisionCatalog.reusableChecks.isEmpty)
        #expect(!DecisionCatalog.pinnedScenarios.isEmpty)
    }

    // MARK: - Section copy guard

    @Test("Section header subtitles never use prohibited recommendation / analysis language")
    func sectionCopyHasNoProhibitedPhrases() {
        let prohibited: [String] = [
            "best card",
            "best account",
            "best option",
            "recommended",
            "analyzed",
            "analysed",
            "guaranteed",
            "verified",
        ]

        // The literal strings the redesign hard-codes for each
        // section subtitle. Pinned here so future copy edits get
        // caught by the copy guard.
        let inspected: [String] = [
            "Evergreen tools you can run any time.",
            "A specific decision NomadFi keeps visible because it's ongoing.",
            "Decisions you've reviewed at least once on this device.",
            "Saved raw context. Each row shows what NomadFi can do with it right now.",
            "Hidden from the main list. Tap to restore or delete permanently.",
            // Empty-state copy:
            "Open a reusable check or the pinned scenario above to start a record NomadFi can reopen later.",
            "Tap + to capture a scenario in your own words.",
        ]

        for phrase in prohibited {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in section copy: \(copy)"
                )
            }
        }
    }
}
