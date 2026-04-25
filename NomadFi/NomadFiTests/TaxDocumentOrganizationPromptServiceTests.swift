// TaxDocumentOrganizationPromptServiceTests.swift
// NomadFi
//
// Pure coverage for the Phase 7E prompt-derivation rules.
//
// `JurisdictionProfile` and `TaxDocument` are SwiftData `@Model`
// types, so building instances requires the main actor. The
// service only reads value-typed fields, so tests stay off
// `ModelContainer` by constructing fresh instances without
// inserting them into a context — same pattern the existing
// `TaxEducationSelectorTests` uses.
//
// Pinned product contract:
//
//   • Empty jurisdictions ⇒ empty prompt list.
//   • Per surfaced region: exactly one action prompt + one
//     recordkeeping prompt, in that order, in selector order
//     (home first, then displayOrder, dedup by region).
//   • Action prompt routes to `.review` when no documents are on
//     file for that region, `.archive` when at least one is.
//   • Recordkeeping prompts cite IRS / CRA / IRD only — and only
//     CRA's "six years" line is restated because that exact
//     number is published on the regulator's page.
//   • Banned suitability / filing / completeness vocabulary never
//     appears in any prompt copy.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct TaxDocumentOrganizationPromptServiceTests {

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

    private func document(
        jurisdiction: String,
        taxYear: Int = 2026
    ) -> TaxDocument {
        TaxDocument(
            merchantName: "Test merchant",
            amount: 12.34,
            currencyCode: .usd,
            documentDate: .now,
            taxYear: taxYear,
            jurisdiction: jurisdiction
        )
    }

    // MARK: - Empty input

    @Test("Empty jurisdictions ⇒ empty prompt list (the UI hides the section)")
    func emptyJurisdictionsReturnEmpty() {
        #expect(
            TaxDocumentOrganizationPromptService.prompts(
                for: [],
                documents: []
            ).isEmpty
        )
    }

    @Test("Documents alone, with no active jurisdictions, still produce no prompts")
    func documentsWithoutJurisdictionsReturnEmpty() {
        let docs = [document(jurisdiction: "US")]
        #expect(
            TaxDocumentOrganizationPromptService.prompts(
                for: [],
                documents: docs
            ).isEmpty
        )
    }

    // MARK: - Ordering + structure

    @Test("Each surfaced region produces exactly two prompts, in action-then-recordkeeping order")
    func twoPromptsPerRegionInOrder() {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [profile(countryCode: "US", isHome: true)],
            documents: []
        )
        #expect(prompts.count == 2)
        #expect(prompts[0].region == .unitedStates)
        #expect(prompts[0].kind == .scanFirstDocument)
        #expect(prompts[1].region == .unitedStates)
        #expect(prompts[1].kind == .recordkeepingPrinciples)
    }

    @Test("Region order mirrors selector — home first, then displayOrder, dedup by region")
    func regionOrderIsHomeFirst() {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [
                profile(countryCode: "CA", isHome: false, displayOrder: 1),
                profile(countryCode: "US", isHome: true, displayOrder: 0),
                profile(countryCode: "us", isHome: false, displayOrder: 2),
            ],
            documents: []
        )
        // 2 regions × 2 prompts = 4 (the duplicate "us" collapses).
        #expect(prompts.count == 4)
        #expect(prompts.map(\.region) == [
            .unitedStates,
            .unitedStates,
            .canada,
            .canada,
        ])
    }

    @Test("Unsupported country codes are silently skipped — no FR / GB placeholder")
    func unsupportedCodesSkipped() {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [
                profile(countryCode: "US", isHome: true),
                profile(countryCode: "FR", isHome: false, displayOrder: 1),
            ],
            documents: []
        )
        #expect(prompts.allSatisfy { $0.region == .unitedStates })
    }

    // MARK: - Action-prompt state

    @Test("Empty archive for the region routes the action prompt to Review")
    func emptyArchiveRoutesToReview() throws {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [profile(countryCode: "US", isHome: true)],
            documents: []
        )
        let action = try #require(prompts.first { $0.kind == .scanFirstDocument })
        #expect(action.actionTarget == .review)
        #expect(action.actionTitle == "Open Review")
    }

    @Test("At least one document for the region routes the action prompt to Archive")
    func populatedArchiveRoutesToArchive() throws {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [profile(countryCode: "US", isHome: true)],
            documents: [document(jurisdiction: "US")]
        )
        let action = try #require(prompts.first { $0.kind == .verifyArchive })
        #expect(action.actionTarget == .archive)
        #expect(action.actionTitle == "Open Archive")
    }

    @Test("Region matching is case-insensitive against TaxDocument.jurisdiction")
    func regionMatchingIsCaseInsensitive() throws {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [profile(countryCode: "US", isHome: true)],
            documents: [document(jurisdiction: "us")]
        )
        let action = try #require(prompts.first { $0.kind == .verifyArchive })
        #expect(action.actionTarget == .archive)
    }

    @Test("Cross-region documents do not bleed: a CA document keeps the US action prompt at scanFirstDocument")
    func crossRegionDocumentsDoNotBleed() throws {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [
                profile(countryCode: "US", isHome: true),
                profile(countryCode: "CA", isHome: false, displayOrder: 1),
            ],
            documents: [document(jurisdiction: "CA")]
        )
        let usAction = try #require(
            prompts.first { $0.region == .unitedStates && $0.kind == .scanFirstDocument }
        )
        #expect(usAction.actionTarget == .review)

        let caAction = try #require(
            prompts.first { $0.region == .canada && $0.kind == .verifyArchive }
        )
        #expect(caAction.actionTarget == .archive)
    }

    // MARK: - Recordkeeping prompts

    @Test("U.S. recordkeeping prompt cites IRS only — both How long and What kind")
    func usRecordkeepingCitesIRSOnly() throws {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [profile(countryCode: "US", isHome: true)],
            documents: []
        )
        let rk = try #require(prompts.first { $0.kind == .recordkeepingPrinciples })
        #expect(!rk.sources.isEmpty)
        for source in rk.sources {
            #expect(source.publisher == "IRS")
        }
        let citedIDs = Set(rk.sources.map(\.id))
        #expect(citedIDs.contains("irs-keep-records-how-long"))
        #expect(citedIDs.contains("irs-keep-records-what-kind"))
        #expect(rk.actionTarget == .none)
        #expect(rk.actionTitle == nil)
    }

    @Test("Canada recordkeeping prompt cites CRA only and is the only one that restates a duration")
    func canadaRecordkeepingCitesCRAAndRestatesSixYears() throws {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [profile(countryCode: "CA", isHome: true)],
            documents: []
        )
        let rk = try #require(prompts.first { $0.kind == .recordkeepingPrinciples })
        #expect(rk.sources.count == 1)
        #expect(rk.sources.first?.publisher == "CRA")
        // CRA is the only regulator whose own page publishes a
        // single retention duration the prompt restates.
        #expect(rk.body.localizedStandardContains("six years"))
    }

    @Test("Trinidad and Tobago recordkeeping prompt cites IRD only and stays generic about retention")
    func trinidadRecordkeepingCitesIRDOnlyAndStaysGeneric() throws {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [profile(countryCode: "TT", isHome: true)],
            documents: []
        )
        let rk = try #require(prompts.first { $0.kind == .recordkeepingPrinciples })
        #expect(rk.sources.count == 1)
        #expect(rk.sources.first?.publisher == "IRD Trinidad and Tobago")
        // Stays generic — never invents a retention number.
        let bannedDurations = ["six years", "seven years", "five years", "ten years"]
        for phrase in bannedDurations {
            #expect(
                !rk.body.localizedStandardContains(phrase),
                "TT prompt must stay generic; found '\(phrase)' in body."
            )
        }
    }

    // MARK: - Copy guard

    @Test("No prompt copy uses banned filing / suitability / completeness vocabulary")
    func copyGuardOnPromptVocabulary() {
        let bannedPhrases: [String] = [
            "you should file",
            "you must file",
            "this is deductible",
            "you qualify",
            "compliant",
            "you have everything you need",
            "all your records",
            "everything you need",
            "tax advice",
            "legal advice",
            "professional advice",
            "guaranteed",
            "deduct this",
            "we recommend",
        ]

        let allRegions = [
            profile(countryCode: "US", isHome: true, displayOrder: 0),
            profile(countryCode: "CA", isHome: false, displayOrder: 1),
            profile(countryCode: "TT", isHome: false, displayOrder: 2),
        ]
        // Combine empty and populated archive states so both the
        // scanFirstDocument and verifyArchive copy is inspected.
        let combinedDocs = [
            document(jurisdiction: "CA"),
            document(jurisdiction: "TT"),
        ]
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: allRegions,
            documents: combinedDocs
        )

        var inspected: [String] = []
        for prompt in prompts {
            inspected.append(prompt.title)
            inspected.append(prompt.body)
            if let title = prompt.actionTitle { inspected.append(title) }
            for source in prompt.sources {
                inspected.append(source.title)
                inspected.append(source.summary)
                inspected.append(source.publisher)
            }
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in prompt copy: \(copy)"
                )
            }
        }
    }

    // MARK: - Action-prompt sources

    @Test("Action prompts (scanFirstDocument / verifyArchive) have no sources — they describe NomadFi's surfaces, not regulator material")
    func actionPromptsHaveNoSources() {
        let prompts = TaxDocumentOrganizationPromptService.prompts(
            for: [
                profile(countryCode: "US", isHome: true),
                profile(countryCode: "CA", isHome: false, displayOrder: 1),
            ],
            documents: [document(jurisdiction: "CA")]
        )
        for prompt in prompts where prompt.kind != .recordkeepingPrinciples {
            #expect(
                prompt.sources.isEmpty,
                "Action prompt \(prompt.id) must not carry a regulator citation."
            )
        }
    }
}
