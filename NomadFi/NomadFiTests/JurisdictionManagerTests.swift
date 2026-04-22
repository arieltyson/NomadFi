// JurisdictionManagerTests.swift
// NomadFi
//
// Coverage for post-onboarding jurisdiction management: add, remove,
// home-reassignment, dependency protection, display-order packing,
// and legacy-data repair.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct JurisdictionManagerTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: JurisdictionProfile.self,
            Account.self,
            Transaction.self,
            Subscription.self,
            TaxDocument.self,
            Budget.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    @MainActor
    private func seed(
        _ codes: [String],
        home: String? = nil,
        in context: ModelContext
    ) throws -> [JurisdictionProfile] {
        var profiles: [JurisdictionProfile] = []
        for (index, code) in codes.enumerated() {
            guard let info = JurisdictionInfo.supported.first(where: { $0.id == code }) else {
                continue
            }
            let profile = JurisdictionProfile(
                countryCode: info.id,
                countryName: info.name,
                currencyCode: info.currencyCode,
                isHome: code == home,
                displayOrder: index
            )
            context.insert(profile)
            profiles.append(profile)
        }
        try context.save()
        return profiles
    }

    // MARK: - Add

    @Test("Adding a supported jurisdiction creates a persisted profile")
    func addSupportedJurisdictionCreatesProfile() throws {
        let context = try makeContext()
        let manager = JurisdictionManager(modelContext: context)

        let added = try manager.addJurisdiction(with: "CA")

        #expect(added.countryCode == "CA")
        #expect(added.countryName == "Canada")
        #expect(added.isHome == true) // first profile becomes home
        #expect(try manager.activeProfiles().count == 1)
    }

    @Test("Adding the same country twice never duplicates")
    func addDuplicateIsIdempotent() throws {
        let context = try makeContext()
        let manager = JurisdictionManager(modelContext: context)

        _ = try manager.addJurisdiction(with: "US")
        _ = try manager.addJurisdiction(with: "US")

        let profiles = try manager.activeProfiles()
        #expect(profiles.count == 1)
        #expect(profiles.first?.countryCode == "US")
    }

    @Test("Adding a country that is not in JurisdictionInfo.supported throws")
    func addUnsupportedThrows() throws {
        let context = try makeContext()
        let manager = JurisdictionManager(modelContext: context)

        #expect(throws: JurisdictionManager.JurisdictionOperationError.self) {
            _ = try manager.addJurisdiction(with: "ZZ")
        }
    }

    // MARK: - Home

    @Test("Setting a home jurisdiction clears any prior home")
    func setHomeClearsPrior() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US"], home: "CA", in: context)
        let manager = JurisdictionManager(modelContext: context)

        let profiles = try manager.activeProfiles()
        let us = profiles.first(where: { $0.countryCode == "US" })!

        try manager.setHomeJurisdiction(us)

        let after = try manager.activeProfiles()
        let homes = after.filter(\.isHome)
        #expect(homes.count == 1)
        #expect(homes.first?.countryCode == "US")
    }

    // MARK: - Remove

    @Test("Removing an unused, non-home jurisdiction succeeds")
    func removeUnusedSucceeds() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US", "GB"], home: "CA", in: context)
        let manager = JurisdictionManager(modelContext: context)

        let gb = try manager.activeProfiles().first(where: { $0.countryCode == "GB" })!
        try manager.removeJurisdiction(gb)

        let after = try manager.activeProfiles()
        #expect(after.map(\.countryCode) == ["CA", "US"])
    }

    @Test("Removing the current home jurisdiction is blocked")
    func removeHomeBlocked() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US"], home: "CA", in: context)
        let manager = JurisdictionManager(modelContext: context)

        let ca = try manager.activeProfiles().first(where: { $0.countryCode == "CA" })!

        #expect(throws: JurisdictionManager.JurisdictionOperationError.cannotRemoveHome) {
            try manager.removeJurisdiction(ca)
        }
    }

    @Test("Removing a jurisdiction with dependent accounts is blocked")
    func removeWithAccountDependencyBlocked() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US"], home: "CA", in: context)
        let account = Account(
            name: "Sample Chequing",
            institutionName: "Sample Bank",
            accountType: .checking,
            currencyCode: .usd,
            jurisdiction: "US"
        )
        context.insert(account)
        try context.save()

        let manager = JurisdictionManager(modelContext: context)
        let us = try manager.activeProfiles().first(where: { $0.countryCode == "US" })!

        do {
            try manager.removeJurisdiction(us)
            Issue.record("Expected removal to be blocked by account dependency")
        } catch let JurisdictionManager.JurisdictionOperationError.hasDependents(report) {
            #expect(report.accountCount == 1)
            #expect(report.hasDependents)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Removing a jurisdiction with dependent subscription/tax document is blocked")
    func removeWithSubscriptionAndTaxDocumentBlocked() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US"], home: "CA", in: context)
        let subscription = Subscription(
            serviceName: "Sample Music",
            amount: 9.99,
            currencyCode: .usd,
            frequency: .monthly,
            nextRenewalDate: .now,
            jurisdiction: "US"
        )
        let taxDocument = TaxDocument(
            merchantName: "Sample Form",
            jurisdiction: "US"
        )
        context.insert(subscription)
        context.insert(taxDocument)
        try context.save()

        let manager = JurisdictionManager(modelContext: context)
        let us = try manager.activeProfiles().first(where: { $0.countryCode == "US" })!
        let report = try manager.dependencyReport(for: us.countryCode)
        #expect(report.subscriptionCount == 1)
        #expect(report.taxDocumentCount == 1)
        #expect(report.hasDependents)

        #expect(throws: (any Error).self) {
            try manager.removeJurisdiction(us)
        }
    }

    @Test("Removing does not touch unrelated financial records")
    func removeDoesNotDeleteUnrelatedRecords() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US", "GB"], home: "CA", in: context)
        let account = Account(
            name: "Sample Chequing",
            institutionName: "Sample Bank",
            accountType: .checking,
            currencyCode: .cad,
            jurisdiction: "CA"
        )
        context.insert(account)
        try context.save()

        let manager = JurisdictionManager(modelContext: context)
        let gb = try manager.activeProfiles().first(where: { $0.countryCode == "GB" })!
        try manager.removeJurisdiction(gb)

        let remainingAccounts = try context.fetch(FetchDescriptor<Account>())
        #expect(remainingAccounts.count == 1)
        #expect(remainingAccounts.first?.jurisdiction == "CA")
    }

    // MARK: - Display order

    @Test("Display order stays contiguous after add/remove cycles")
    func displayOrderRemainsContiguous() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US", "GB"], home: "CA", in: context)
        let manager = JurisdictionManager(modelContext: context)

        let us = try manager.activeProfiles().first(where: { $0.countryCode == "US" })!
        try manager.removeJurisdiction(us)
        _ = try manager.addJurisdiction(with: "IN")

        let profiles = try manager.activeProfiles()
        let orders = profiles.map(\.displayOrder)
        #expect(orders == Array(0..<profiles.count))
    }

    // MARK: - Repair

    @Test("Legacy data with no home jurisdiction is repaired deterministically")
    func repairsMissingHome() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US", "GB"], home: nil, in: context)
        let manager = JurisdictionManager(modelContext: context)

        let winner = try manager.repairHomeJurisdictionIfNeeded()
        #expect(winner != nil)

        let profiles = try manager.activeProfiles()
        #expect(profiles.filter(\.isHome).count == 1)
    }

    @Test("Repair collapses duplicate home flags to a single winner")
    func repairCollapsesDuplicateHomes() throws {
        let context = try makeContext()
        _ = try seed(["CA", "US"], home: nil, in: context)
        // Force both homes on.
        for profile in try context.fetch(FetchDescriptor<JurisdictionProfile>()) {
            profile.isHome = true
        }
        try context.save()

        let manager = JurisdictionManager(modelContext: context)
        _ = try manager.repairHomeJurisdictionIfNeeded()

        let profiles = try manager.activeProfiles()
        #expect(profiles.filter(\.isHome).count == 1)
    }

    @Test("Repair with no profiles is a no-op")
    func repairNoProfilesIsNoop() throws {
        let context = try makeContext()
        let manager = JurisdictionManager(modelContext: context)
        let winner = try manager.repairHomeJurisdictionIfNeeded()
        #expect(winner == nil)
    }
}
