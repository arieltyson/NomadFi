// DecisionDraftLifecycleTests.swift
// NomadFi
//
// Coverage for Decision Draft Lifecycle v1:
//
//   - Edit mode pre-fills the form from an existing draft.
//   - Saving in edit mode mutates the same record (no duplicate).
//   - Edit preserves `createdAt` and refreshes `updatedAt`.
//   - Edit cannot erase a draft through an empty scenario.
//   - Edit does not mutate `statusRawValue` (editing an archived
//     draft leaves it archived).
//   - `DecisionDraftStore.archive` / `.restore` flip status and
//     stamp `updatedAt` without creating duplicates.
//   - `DecisionDraftStore.delete` removes only the targeted draft.
//   - The Decision Assistant's "active" predicate (status ==
//     `needsEngine`) excludes archived drafts; the "archived"
//     predicate excludes active drafts. No overlap.
//   - Drafts remain outside `DecisionCatalog`.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct DecisionDraftLifecycleTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DecisionDraftRecord.self,
            Account.self,
            Transaction.self,
            Subscription.self,
            Budget.self,
            ExchangeRate.self,
            JurisdictionProfile.self,
            Currency.self,
            TaxDocument.self,
            ScenarioDecisionRecord.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func insertFixture(
        into context: ModelContext,
        title: String = "Summer laptop",
        scenario: String = "Deciding between Amazon ACC and Wise USD.",
        kind: DecisionDraftKind = .purchase,
        amount: Double? = 1_899,
        currency: CurrencyCode = .usd,
        status: DecisionDraftStatus = .needsEngine,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) throws -> DecisionDraftRecord {
        let record = DecisionDraftRecord(
            title: title,
            scenarioText: scenario,
            kind: kind,
            merchantName: "Amazon",
            locationText: "San Francisco",
            amount: amount,
            currencyCode: currency,
            timingText: "Before arrival",
            notes: "Tracking Airbnb check-in.",
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(record)
        try context.save()
        return record
    }

    // MARK: - Edit mode

    @Test("Edit-mode view model pre-fills every field from the existing draft")
    func editPrefillsFields() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context)

        let vm = DecisionDraftFormViewModel(editing: fixture)

        #expect(vm.mode.isEditing)
        #expect(vm.title == "Summer laptop")
        #expect(vm.scenarioText == "Deciding between Amazon ACC and Wise USD.")
        #expect(vm.kind == .purchase)
        #expect(vm.merchantName == "Amazon")
        #expect(vm.locationText == "San Francisco")
        #expect(vm.amountText == "1899")
        #expect(vm.currencyCode == .usd)
        #expect(vm.timingText == "Before arrival")
        #expect(vm.notes == "Tracking Airbnb check-in.")
    }

    @Test("Edit-mode pre-fill preserves decimal precision when amount is non-integer")
    func editPrefillsDecimalAmount() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context, amount: 1_899.5)

        let vm = DecisionDraftFormViewModel(editing: fixture)
        #expect(vm.amountText == "1899.5")
    }

    @Test("Editing updates the same record — no duplicates left in SwiftData")
    func editUpdatesSameRecord() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context)
        let fixtureID = fixture.draftID

        let vm = DecisionDraftFormViewModel(editing: fixture)
        vm.scenarioText = "Revised: ordering through Chase USD instead."
        vm.merchantName = "Amazon.com"

        let saved = try #require(vm.save(into: context))
        #expect(saved === fixture)
        #expect(saved.draftID == fixtureID)

        let all = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        #expect(all.count == 1)
        #expect(all.first?.scenarioText == "Revised: ordering through Chase USD instead.")
        #expect(all.first?.merchantName == "Amazon.com")
    }

    @Test("Editing stamps updatedAt but preserves createdAt")
    func editPreservesCreatedAtAndRefreshesUpdatedAt() throws {
        let context = try makeContext()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let fixture = try insertFixture(
            into: context,
            createdAt: originalCreatedAt,
            updatedAt: originalUpdatedAt
        )

        let vm = DecisionDraftFormViewModel(editing: fixture)
        vm.scenarioText = "Tiny edit."

        let before = Date.now
        let saved = try #require(vm.save(into: context))
        let after = Date.now

        #expect(saved.createdAt == originalCreatedAt)
        #expect(saved.updatedAt > originalUpdatedAt)
        #expect(saved.updatedAt >= before && saved.updatedAt <= after)
    }

    @Test("Edit mode cannot save an empty scenario — the draft body stays intact")
    func editRequiresScenarioText() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context)

        let vm = DecisionDraftFormViewModel(editing: fixture)
        vm.scenarioText = "   \n  "
        #expect(!vm.canSave)
        #expect(vm.save(into: context) == nil)

        // Fixture must be unchanged after the rejected save.
        #expect(fixture.scenarioText == "Deciding between Amazon ACC and Wise USD.")
    }

    @Test("Editing an archived draft does not silently un-archive it")
    func editDoesNotFlipStatus() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context, status: .archived)

        let vm = DecisionDraftFormViewModel(editing: fixture)
        vm.scenarioText = "Archived note, just tweaking wording."

        let saved = try #require(vm.save(into: context))
        #expect(saved.status == .archived)
    }

    // MARK: - Archive / restore

    @Test("Archive flips status to archived and stamps updatedAt")
    func archiveUpdatesStatusAndTimestamp() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context)
        let originalUpdatedAt = fixture.updatedAt

        let before = Date.now
        DecisionDraftStore.archive(fixture, in: context)
        let after = Date.now

        #expect(fixture.status == .archived)
        #expect(fixture.updatedAt > originalUpdatedAt)
        #expect(fixture.updatedAt >= before && fixture.updatedAt <= after)
    }

    @Test("Restore flips status back to needsEngine and stamps updatedAt")
    func restoreUpdatesStatusAndTimestamp() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context, status: .archived)
        let originalUpdatedAt = fixture.updatedAt

        let before = Date.now
        DecisionDraftStore.restore(fixture, in: context)
        let after = Date.now

        #expect(fixture.status == .needsEngine)
        #expect(fixture.updatedAt > originalUpdatedAt)
        #expect(fixture.updatedAt >= before && fixture.updatedAt <= after)
    }

    @Test("Archiving an already-archived draft is a no-op that leaves updatedAt alone")
    func archiveIsIdempotent() throws {
        let context = try makeContext()
        let frozenTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let fixture = try insertFixture(
            into: context,
            status: .archived,
            updatedAt: frozenTimestamp
        )

        DecisionDraftStore.archive(fixture, in: context)

        #expect(fixture.status == .archived)
        #expect(fixture.updatedAt == frozenTimestamp)
    }

    @Test("Restoring an active draft is a no-op that leaves updatedAt alone")
    func restoreIsIdempotent() throws {
        let context = try makeContext()
        let frozenTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let fixture = try insertFixture(
            into: context,
            status: .needsEngine,
            updatedAt: frozenTimestamp
        )

        DecisionDraftStore.restore(fixture, in: context)

        #expect(fixture.status == .needsEngine)
        #expect(fixture.updatedAt == frozenTimestamp)
    }

    // MARK: - Delete

    @Test("Delete removes only the targeted draft, leaving others intact")
    func deleteRemovesOnlySelected() throws {
        let context = try makeContext()
        let a = try insertFixture(into: context, title: "A", scenario: "First")
        let b = try insertFixture(into: context, title: "B", scenario: "Second")
        let c = try insertFixture(into: context, title: "C", scenario: "Third")

        DecisionDraftStore.delete(b, in: context)

        let remaining = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        let remainingTitles = Set(remaining.map(\.title))
        #expect(remainingTitles == Set([a.title, c.title]))
        #expect(remaining.count == 2)
    }

    // MARK: - Query partitioning

    @Test("Active drafts predicate excludes archived and includes active")
    func activeQueryExcludesArchived() throws {
        let context = try makeContext()
        let active = try insertFixture(
            into: context,
            title: "Active",
            scenario: "Active draft"
        )
        _ = try insertFixture(
            into: context,
            title: "Archived",
            scenario: "Archived draft",
            status: .archived
        )

        let activeRawValue = DecisionDraftStatus.needsEngine.rawValue
        let activePredicate = #Predicate<DecisionDraftRecord> {
            $0.statusRawValue == activeRawValue
        }
        let activeDescriptor = FetchDescriptor<DecisionDraftRecord>(
            predicate: activePredicate
        )

        let fetched = try context.fetch(activeDescriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.draftID == active.draftID)
    }

    @Test("Archived drafts predicate excludes active and includes archived")
    func archivedQueryExcludesActive() throws {
        let context = try makeContext()
        _ = try insertFixture(
            into: context,
            title: "Active",
            scenario: "Active draft"
        )
        let archived = try insertFixture(
            into: context,
            title: "Archived",
            scenario: "Archived draft",
            status: .archived
        )

        let archivedRawValue = DecisionDraftStatus.archived.rawValue
        let archivedPredicate = #Predicate<DecisionDraftRecord> {
            $0.statusRawValue == archivedRawValue
        }
        let archivedDescriptor = FetchDescriptor<DecisionDraftRecord>(
            predicate: archivedPredicate
        )

        let fetched = try context.fetch(archivedDescriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.draftID == archived.draftID)
    }

    @Test("After archiving an active draft, it moves from active to archived query without duplication")
    func archiveMovesBetweenQueries() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context)

        DecisionDraftStore.archive(fixture, in: context)

        let activeRawValue = DecisionDraftStatus.needsEngine.rawValue
        let archivedRawValue = DecisionDraftStatus.archived.rawValue
        let activeCount = try context.fetch(
            FetchDescriptor<DecisionDraftRecord>(
                predicate: #Predicate { $0.statusRawValue == activeRawValue }
            )
        ).count
        let archivedCount = try context.fetch(
            FetchDescriptor<DecisionDraftRecord>(
                predicate: #Predicate { $0.statusRawValue == archivedRawValue }
            )
        ).count

        #expect(activeCount == 0)
        #expect(archivedCount == 1)
    }

    // MARK: - Catalog isolation

    @Test("Lifecycle transitions never add drafts to DecisionCatalog")
    func lifecycleDoesNotPromoteDraftsIntoCatalog() throws {
        let context = try makeContext()
        let fixture = try insertFixture(into: context)
        DecisionDraftStore.archive(fixture, in: context)
        DecisionDraftStore.restore(fixture, in: context)

        let catalogIDs = Set(DecisionCatalog.all.map(\.id.rawValue))
        #expect(!catalogIDs.contains(fixture.draftID.uuidString))
        // Catalog entries are tightly controlled — both current
        // engines (Amazon arrival order and Credit timing check) are
        // in the catalog; drafts are not.
        #expect(DecisionCatalog.all.map(\.id) == [.amazonArrivalOrder, .creditTimingCheck])
    }
}
