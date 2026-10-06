// InvestingLearnRegionTests.swift
// NomadFi
//
// Pins the lookup behind Investing Learn's region cards: a card only
// opens a region that is one of the person's jurisdictions.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct InvestingLearnRegionTests {

    @Test("A region card opens that region's bundle, and only for the person's jurisdictions")
    func bundleLookup() {
        let viewModel = InvestingLearnViewModel()
        viewModel.refresh(from: [
            JurisdictionProfile(
                countryCode: "CA",
                countryName: "Canada",
                currencyCode: .cad,
                isHome: true,
                displayOrder: 0
            ),
        ])

        #expect(viewModel.bundle(for: .canada)?.region == .canada)
        #expect(viewModel.bundle(for: .unitedStates) == nil)
    }
}
