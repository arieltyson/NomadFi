// TaxEducationSelector.swift
// NomadFi
//
// Pure selector that picks which regions the education section
// should show for a user. Driven entirely by active
// `JurisdictionProfile` records — never by geolocation, IP, or
// any inferred signal.
//
// Rules (pinned in `TaxEducationSelectorTests`):
//   • Home jurisdiction first.
//   • Then other active jurisdictions in `displayOrder` order.
//   • Each region appears once — duplicates are collapsed by the
//     region enum, not by string comparison.
//   • Regions the catalogue does not cover are skipped silently.
//   • Empty input → empty output (UI hides the section).

import Foundation

/// Per-region content bundle surfaced to the UI. Built by
/// `TaxEducationSelector.regionBundles(for:)` so the view-model
/// doesn't assemble content itself.
struct TaxEducationRegionBundle: Sendable, Equatable, Identifiable {
    var id: String { region.rawValue }
    let region: TaxEducationRegion
    /// `true` for the user's home jurisdiction, if it matches this
    /// region. Home bundles render first.
    let isHome: Bool
    let checklist: TaxEducationChecklist
    let lessons: [TaxEducationLesson]
}

/// Pure namespace — no state.
enum TaxEducationSelector {

    // MARK: - Public API

    /// Picks the ordered regions to render for `jurisdictions`.
    /// Deterministic: same input → same output. Home first, then
    /// the rest in `displayOrder`, de-duplicated by region enum.
    static func orderedRegions(
        for jurisdictions: [JurisdictionProfile]
    ) -> [TaxEducationRegion] {
        let homeFirst = jurisdictions.sorted { lhs, rhs in
            if lhs.isHome != rhs.isHome {
                return lhs.isHome
            }
            return lhs.displayOrder < rhs.displayOrder
        }

        var seen = Set<TaxEducationRegion>()
        var ordered: [TaxEducationRegion] = []
        for jurisdiction in homeFirst {
            guard let region = TaxEducationRegion.fromCountryCode(jurisdiction.countryCode) else {
                continue
            }
            if seen.insert(region).inserted {
                ordered.append(region)
            }
        }
        return ordered
    }

    /// Convenience wrapper — assembles a per-region content
    /// bundle in the order `orderedRegions(for:)` returns.
    static func regionBundles(
        for jurisdictions: [JurisdictionProfile]
    ) -> [TaxEducationRegionBundle] {
        let regions = orderedRegions(for: jurisdictions)
        let homeRegion = homeRegion(for: jurisdictions)
        return regions.map { region in
            let lessons = TaxEducationCatalog
                .lessons(for: region)
                .filter(TaxEducationCatalog.isValid)
            return TaxEducationRegionBundle(
                region: region,
                isHome: region == homeRegion,
                checklist: TaxEducationCatalog.checklist(for: region),
                lessons: lessons
            )
        }
    }

    // MARK: - Private

    private static func homeRegion(
        for jurisdictions: [JurisdictionProfile]
    ) -> TaxEducationRegion? {
        let home = jurisdictions.first { $0.isHome }
        guard let code = home?.countryCode else { return nil }
        return TaxEducationRegion.fromCountryCode(code)
    }
}
