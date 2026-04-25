// InvestingEducationSelector.swift
// NomadFi
//
// Pure selector that picks which regions the Investing Learn surface
// should show. Driven entirely by active `JurisdictionProfile`
// records — never by geolocation or any inferred signal.
//
// Rules pinned in `InvestingEducationSelectorTests`:
//   • Home jurisdiction first.
//   • Then other active jurisdictions in `displayOrder` order.
//   • Each region appears once — duplicates collapsed by enum.
//   • Regions the catalogue does not cover are skipped silently.
//   • Empty input → empty output (UI hides the section).

import Foundation

/// Per-region content bundle the UI consumes. Built by
/// `InvestingEducationSelector.regionBundles(for:)`.
struct InvestingEducationRegionBundle: Sendable, Equatable, Identifiable {
    var id: String { region.rawValue }
    let region: InvestingEducationRegion
    /// `true` for the user's home jurisdiction, when it matches
    /// this region. Home bundles render first.
    let isHome: Bool
    let checklist: InvestingEducationChecklist
    let lessons: [InvestingEducationLesson]

    init(
        region: InvestingEducationRegion,
        isHome: Bool,
        checklist: InvestingEducationChecklist,
        lessons: [InvestingEducationLesson]
    ) {
        self.region = region
        self.isHome = isHome
        self.checklist = checklist
        self.lessons = lessons
    }
}

enum InvestingEducationSelector {

    static func orderedRegions(
        for jurisdictions: [JurisdictionProfile]
    ) -> [InvestingEducationRegion] {
        let homeFirst = jurisdictions.sorted { lhs, rhs in
            if lhs.isHome != rhs.isHome {
                return lhs.isHome
            }
            return lhs.displayOrder < rhs.displayOrder
        }

        var seen = Set<InvestingEducationRegion>()
        var ordered: [InvestingEducationRegion] = []
        for jurisdiction in homeFirst {
            guard let region = InvestingEducationRegion.fromCountryCode(
                jurisdiction.countryCode
            ) else {
                continue
            }
            if seen.insert(region).inserted {
                ordered.append(region)
            }
        }
        return ordered
    }

    /// Convenience wrapper — assembles per-region content bundles
    /// in the order `orderedRegions(for:)` returns.
    static func regionBundles(
        for jurisdictions: [JurisdictionProfile]
    ) -> [InvestingEducationRegionBundle] {
        let regions = orderedRegions(for: jurisdictions)
        let homeRegion = homeRegion(for: jurisdictions)
        return regions.map { region in
            let lessons = InvestingEducationCatalog
                .lessons(for: region)
                .filter(InvestingEducationCatalog.isValid)
            return InvestingEducationRegionBundle(
                region: region,
                isHome: region == homeRegion,
                checklist: InvestingEducationCatalog.checklist(for: region),
                lessons: lessons
            )
        }
    }

    // MARK: - Private

    private static func homeRegion(
        for jurisdictions: [JurisdictionProfile]
    ) -> InvestingEducationRegion? {
        let home = jurisdictions.first { $0.isHome }
        guard let code = home?.countryCode else { return nil }
        return InvestingEducationRegion.fromCountryCode(code)
    }
}
