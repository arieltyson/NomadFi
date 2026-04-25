// TaxDocumentOrganizationPromptService.swift
// NomadFi
//
// Pure derivation layer for the Phase 7E document-organization
// prompts. Inputs are existing records — active jurisdictions and
// `TaxDocument` rows the archive already holds. Outputs are
// deterministic prompt cards the Tax Vault Learn surface renders
// near each region's checklist context.
//
// Rules pinned in `TaxDocumentOrganizationPromptServiceTests`:
//
//   • Empty jurisdictions ⇒ empty prompt list (the UI hides the
//     section entirely).
//   • Region order mirrors the existing `TaxEducationSelector`:
//     home jurisdiction first, then displayOrder, dedup by region.
//   • For each surfaced region, the service emits a state-
//     dependent action prompt — `scanFirstDocument` if the archive
//     holds no documents for that region, `verifyArchive` if it
//     holds at least one — and a `recordkeepingPrinciples` prompt
//     citing the right official regulator page.
//   • Region matching against `TaxDocument.jurisdiction` is
//     case-insensitive on the country-code raw value so a "us" /
//     "US" archive entry both count as U.S. records.
//   • Recordkeeping copy never claims a uniform retention duration
//     across jurisdictions; CRA's "at least six years" is the only
//     specific duration cited because it is the only one the
//     primary source publishes that bluntly. U.S. and TT prompts
//     stay procedural.
//
// No persistence; no IO. The service is a pure function over its
// inputs, so callers can recompute on every render.

import Foundation
import OSLog

enum TaxDocumentOrganizationPromptService {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "TaxDocumentOrganizationPrompt"
    )

    // MARK: - Public API

    /// Produces the ordered prompt list to render in Tax Vault
    /// Learn. Pure over its inputs.
    @MainActor
    static func prompts(
        for jurisdictions: [JurisdictionProfile],
        documents: [TaxDocument]
    ) -> [TaxDocumentOrganizationPrompt] {
        let regions = orderedRegions(for: jurisdictions)
        guard !regions.isEmpty else { return [] }

        var output: [TaxDocumentOrganizationPrompt] = []
        for region in regions {
            output.append(actionPrompt(for: region, documents: documents))
            output.append(recordkeepingPrompt(for: region))
        }
        return output
    }

    // MARK: - Region ordering

    private static func orderedRegions(
        for jurisdictions: [JurisdictionProfile]
    ) -> [TaxEducationRegion] {
        let homeFirst = jurisdictions.sorted { lhs, rhs in
            if lhs.isHome != rhs.isHome { return lhs.isHome }
            return lhs.displayOrder < rhs.displayOrder
        }

        var seen: Set<TaxEducationRegion> = []
        var ordered: [TaxEducationRegion] = []
        for jurisdiction in homeFirst {
            guard let region = TaxEducationRegion.fromCountryCode(
                jurisdiction.countryCode
            ) else { continue }
            if seen.insert(region).inserted {
                ordered.append(region)
            }
        }
        return ordered
    }

    // MARK: - Action prompt

    private static func actionPrompt(
        for region: TaxEducationRegion,
        documents: [TaxDocument]
    ) -> TaxDocumentOrganizationPrompt {
        let regionDocuments = documents.filter { matchesRegion($0, region: region) }
        if regionDocuments.isEmpty {
            return TaxDocumentOrganizationPrompt(
                id: "\(region.rawValue)-scan-first-document",
                region: region,
                kind: .scanFirstDocument,
                title: "Start the \(region.displayName) archive",
                body: "Tax Vault has no \(region.displayName) documents on file yet. Review is where you scan or upload the first one — NomadFi reads it on device and saves it grouped by tax year and jurisdiction.",
                actionTarget: .review,
                actionTitle: "Open Review",
                sources: []
            )
        }

        return TaxDocumentOrganizationPrompt(
            id: "\(region.rawValue)-verify-archive",
            region: region,
            kind: .verifyArchive,
            title: "Verify the \(region.displayName) archive",
            body: "Archive groups your \(region.displayName) documents by tax year and jurisdiction. A quick pass through the latest year is the calm way to confirm NomadFi's grouping matches your own mental model before you rely on it.",
            actionTarget: .archive,
            actionTitle: "Open Archive",
            sources: []
        )
    }

    // MARK: - Recordkeeping prompt

    private static func recordkeepingPrompt(
        for region: TaxEducationRegion
    ) -> TaxDocumentOrganizationPrompt {
        switch region {
        case .unitedStates:
            return TaxDocumentOrganizationPrompt(
                id: "us-recordkeeping-principles",
                region: region,
                kind: .recordkeepingPrinciples,
                title: "U.S. recordkeeping principles",
                body: "The IRS publishes which kinds of records to keep and how the retention window depends on the period of limitations for the item involved. There is no single uniform duration — the IRS pages frame retention by the underlying record type.",
                actionTarget: .none,
                actionTitle: nil,
                sources: [
                    TaxEducationSource(
                        id: "irs-keep-records-how-long",
                        publisher: "IRS",
                        title: "How long should I keep records?",
                        url: URL(string: "https://www.eitc.irs.gov/businesses/small-businesses-self-employed/how-long-should-i-keep-records")!,
                        summary: "IRS small-business / self-employed page on retention windows tied to the period of limitations for each record type."
                    ),
                    TaxEducationSource(
                        id: "irs-keep-records-what-kind",
                        publisher: "IRS",
                        title: "What kind of records should I keep",
                        url: URL(string: "https://www.irs.gov/businesses/small-businesses-self-employed/what-kind-of-records-should-i-keep")!,
                        summary: "IRS reference for the categories of records the agency expects taxpayers to keep, with examples by document type."
                    ),
                ]
            )
        case .canada:
            return TaxDocumentOrganizationPrompt(
                id: "ca-recordkeeping-principles",
                region: region,
                kind: .recordkeepingPrinciples,
                title: "Canada recordkeeping principles",
                body: "CRA publishes that you must keep your supporting documents for at least six years from the end of the tax year they relate to. Reading the CRA page is the procedural anchor before disposing of older records.",
                actionTarget: .none,
                actionTitle: nil,
                sources: [
                    TaxEducationSource(
                        id: "cra-keep-records-six-years",
                        publisher: "CRA",
                        title: "How long should you keep your income tax records?",
                        url: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/long-should-you-keep-your-income-tax-records.html")!,
                        summary: "CRA reference stating that supporting documents must be kept for at least six years from the end of the relevant tax year."
                    )
                ]
            )
        case .trinidadAndTobago:
            return TaxDocumentOrganizationPrompt(
                id: "tt-recordkeeping-principles",
                region: region,
                kind: .recordkeepingPrinciples,
                title: "Trinidad and Tobago recordkeeping principles",
                body: "The IRD's small business person guidance reminds Trinidad and Tobago taxpayers to keep adequate records of their business activity. NomadFi does not infer a specific retention duration here — the IRD page is the canonical reference for current guidance.",
                actionTarget: .none,
                actionTitle: nil,
                sources: [
                    TaxEducationSource(
                        id: "ird-tt-small-business-person",
                        publisher: "IRD Trinidad and Tobago",
                        title: "Small Business Person",
                        url: URL(string: "https://www.ird.gov.tt/small-business-person")!,
                        summary: "IRD landing page for small-business taxpayers, including the expectation to keep adequate records of business activity."
                    )
                ]
            )
        }
    }

    // MARK: - Region matching

    private static func matchesRegion(
        _ document: TaxDocument,
        region: TaxEducationRegion
    ) -> Bool {
        let normalized = document.jurisdiction
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return normalized == region.rawValue
    }
}
