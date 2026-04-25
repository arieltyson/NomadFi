// InvestingEducationSelectorTests.swift
// NomadFi
//
// Pure coverage for the Phase 8A region selector. `JurisdictionProfile`
// is a SwiftData `@Model`, so building instances requires the main
// actor — we stay off `ModelContainer` by constructing them in
// isolation without inserting into a context (the selector only
// reads value-typed fields).

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct InvestingEducationSelectorTests {

    // MARK: - Helpers

    private func profile(
        countryCode: String,
        isHome: Bool = false,
        displayOrder: Int = 0
    ) -> JurisdictionProfile {
        JurisdictionProfile(
            countryCode: countryCode,
            countryName: countryCode,
            currencyCode: .usd,
            isHome: isHome,
            displayOrder: displayOrder
        )
    }

    // MARK: - Ordering

    @Test("Home jurisdiction surfaces first in the region ordering")
    func homeJurisdictionFirst() {
        let usHome = profile(countryCode: "US", isHome: true, displayOrder: 1)
        let canadaSecondary = profile(countryCode: "CA", isHome: false, displayOrder: 0)

        let regions = InvestingEducationSelector.orderedRegions(
            for: [canadaSecondary, usHome]
        )
        #expect(regions.first == .unitedStates)
        #expect(regions == [.unitedStates, .canada])
    }

    @Test("Additional non-home jurisdictions surface in displayOrder after home")
    func additionalJurisdictionsSurfaceInOrder() {
        let home = profile(countryCode: "CA", isHome: true, displayOrder: 0)
        let usSecondary = profile(countryCode: "US", isHome: false, displayOrder: 1)

        let regions = InvestingEducationSelector.orderedRegions(
            for: [usSecondary, home]
        )
        #expect(regions == [.canada, .unitedStates])
    }

    @Test("Duplicate country codes are de-duplicated at the region level")
    func duplicatesCollapsed() {
        let homeUS = profile(countryCode: "US", isHome: true)
        let secondaryUS = profile(countryCode: "us", isHome: false, displayOrder: 1)

        let regions = InvestingEducationSelector.orderedRegions(
            for: [homeUS, secondaryUS]
        )
        #expect(regions == [.unitedStates])
    }

    @Test("Trinidad and Tobago is silently skipped — not yet covered by 8A")
    func trinidadAndTobagoSkippedInPhase8A() {
        let supportedHome = profile(countryCode: "CA", isHome: true)
        let ttSecondary = profile(countryCode: "TT", isHome: false, displayOrder: 1)

        let regions = InvestingEducationSelector.orderedRegions(
            for: [supportedHome, ttSecondary]
        )
        #expect(regions == [.canada])

        let bundles = InvestingEducationSelector.regionBundles(
            for: [supportedHome, ttSecondary]
        )
        #expect(bundles.map(\.region) == [.canada])
    }

    @Test("Unsupported country codes are skipped without producing placeholder bundles")
    func unsupportedCodesSkipped() {
        let supportedHome = profile(countryCode: "US", isHome: true)
        let unsupported = profile(countryCode: "FR", isHome: false, displayOrder: 1)

        let regions = InvestingEducationSelector.orderedRegions(
            for: [supportedHome, unsupported]
        )
        #expect(regions == [.unitedStates])

        let bundles = InvestingEducationSelector.regionBundles(
            for: [supportedHome, unsupported]
        )
        #expect(bundles.map(\.region) == [.unitedStates])
    }

    // MARK: - Empty state

    @Test("Empty jurisdictions → empty ordering + empty bundles (the UI hides the section)")
    func emptyJurisdictionsReturnEmpty() {
        #expect(InvestingEducationSelector.orderedRegions(for: []).isEmpty)
        #expect(InvestingEducationSelector.regionBundles(for: []).isEmpty)
    }

    // MARK: - Bundle composition

    @Test("regionBundles(for:) produces the matching checklist + lessons for every selected region")
    func bundlesHaveCatalogueContent() throws {
        let usHome = profile(countryCode: "US", isHome: true)
        let caSecondary = profile(countryCode: "CA", isHome: false, displayOrder: 1)

        let bundles = InvestingEducationSelector.regionBundles(
            for: [usHome, caSecondary]
        )
        #expect(bundles.count == 2)

        let usBundle = try #require(bundles.first)
        #expect(usBundle.region == .unitedStates)
        #expect(usBundle.isHome == true)
        #expect(usBundle.checklist.region == .unitedStates)
        #expect(usBundle.lessons.allSatisfy { $0.region == .unitedStates })
        #expect(usBundle.lessons.count >= 3)

        let caBundle = bundles[1]
        #expect(caBundle.region == .canada)
        #expect(caBundle.isHome == false)
        #expect(caBundle.checklist.region == .canada)
        #expect(caBundle.lessons.allSatisfy { $0.region == .canada })
    }

    @Test("isHome is only true when the region actually matches the user's home jurisdiction")
    func isHomeOnlyForMatchingRegion() throws {
        let home = profile(countryCode: "CA", isHome: true)
        let usSecondary = profile(countryCode: "US", isHome: false, displayOrder: 1)

        let bundles = InvestingEducationSelector.regionBundles(
            for: [home, usSecondary]
        )
        #expect(bundles.map(\.region) == [.canada, .unitedStates])
        #expect(bundles[0].isHome == true)
        #expect(bundles[1].isHome == false)
    }

    @Test("Lessons surfaced through the selector all pass the catalogue's validator")
    func selectorOnlyReturnsValidLessons() {
        let usHome = profile(countryCode: "US", isHome: true)
        let caSecondary = profile(countryCode: "CA", isHome: false, displayOrder: 1)

        let bundles = InvestingEducationSelector.regionBundles(
            for: [usHome, caSecondary]
        )
        for bundle in bundles {
            for lesson in bundle.lessons {
                #expect(InvestingEducationCatalog.isValid(lesson))
            }
        }
    }
}
