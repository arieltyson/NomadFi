// TaxVaultArchiveGroupingTests.swift
// NomadFi
//
// Pins that the Archive's jurisdiction grouping never drops a
// document. Models are built without a context, as in
// `TaxDocumentOrganizationPromptServiceTests`.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct TaxVaultArchiveGroupingTests {

    @Test("Documents follow profile order, one group per matched jurisdiction")
    func matchedDocumentsFollowProfileOrder() {
        let groups = TaxVaultViewModel().documentsByJurisdiction(
            [document("Coffee", in: "US"), document("Books", in: "CA")],
            jurisdictions: [profile("CA"), profile("US")]
        )

        #expect(groups.map(\.id) == ["CA", "US"])
    }

    @Test("Documents with no matching profile trail in an Other group")
    func unmatchedDocumentsAreKept() {
        let groups = TaxVaultViewModel().documentsByJurisdiction(
            [
                document("Coffee", in: "US"),
                document("Unassigned", in: ""),
                document("Removed region", in: "GB"),
            ],
            jurisdictions: [profile("US")]
        )

        #expect(groups.map(\.id) == ["US", TaxDocumentJurisdictionGroup.otherID])
        #expect(groups.last?.documents.map(\.merchantName) == ["Unassigned", "Removed region"])
        #expect(groups.flatMap(\.documents).count == 3)
    }

    @Test("No Other group when every document matches a profile")
    func noOtherGroupWhenAllMatch() {
        let groups = TaxVaultViewModel().documentsByJurisdiction(
            [document("Coffee", in: "US")],
            jurisdictions: [profile("US")]
        )

        #expect(!groups.contains { $0.id == TaxDocumentJurisdictionGroup.otherID })
    }

    private func profile(_ countryCode: String) -> JurisdictionProfile {
        JurisdictionProfile(
            countryCode: countryCode,
            countryName: countryCode,
            currencyCode: .usd,
            isHome: false,
            displayOrder: 0
        )
    }

    private func document(_ merchantName: String, in jurisdiction: String) -> TaxDocument {
        TaxDocument(merchantName: merchantName, taxYear: 2026, jurisdiction: jurisdiction)
    }
}
