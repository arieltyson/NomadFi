// TaxEducationRegion.swift
// NomadFi
//
// Supported regions for the Tax Vault education starter. Scope is
// intentionally narrow — only the jurisdictions NomadFi's mission
// already covers (United States, Canada, Trinidad and Tobago).
// New regions must ship with their own locally-authored, source-
// backed content and a `fromCountryCode` mapping before being
// added here.

import Foundation

/// Regions the education catalogue covers.
enum TaxEducationRegion: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case unitedStates = "US"
    case canada = "CA"
    case trinidadAndTobago = "TT"

    var id: String { rawValue }

    /// Friendly name for the UI. Always absolute — never relative
    /// ("your country") — so the surface reads honestly even when
    /// the user has multiple active jurisdictions.
    var displayName: String {
        switch self {
        case .unitedStates: "United States"
        case .canada: "Canada"
        case .trinidadAndTobago: "Trinidad and Tobago"
        }
    }

    /// SF Symbol paired with the name so Differentiate-Without-
    /// Color users still read the region correctly.
    var systemImage: String {
        switch self {
        case .unitedStates: "flag"
        case .canada: "leaf"
        case .trinidadAndTobago: "sun.max"
        }
    }

    // MARK: - Mapping

    /// Resolves a jurisdiction's country code to a supported region.
    /// Case-insensitive so "us" / "US" both map. Returns `nil` for
    /// any region the education catalogue does not cover yet — the
    /// selector hides unknown regions rather than invent content.
    static func fromCountryCode(_ code: String) -> TaxEducationRegion? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return allCases.first { $0.rawValue == normalized }
    }
}
