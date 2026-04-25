// InvestingEducationRegion.swift
// NomadFi
//
// Supported regions for the Phase 8A investing-education starter.
// Intentionally narrower than the tax catalogue: only jurisdictions
// where NomadFi has a primary-source basis for a first cut. United
// States lessons cite Investor.gov + IRS; Canada lessons cite CIRO,
// CIPF, and CRA. Trinidad and Tobago is deferred — TTSEC publishes
// investor-protection material but the per-account-type lessons
// (e.g. retirement-account analogues) lack the primary-source clarity
// the U.S. and Canadian regulators provide. See
// `docs/research/InvestingEducationSourceMap.md` for the rationale.

import Foundation

/// Regions the investing-education starter covers.
enum InvestingEducationRegion: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case unitedStates = "US"
    case canada = "CA"

    var id: String { rawValue }

    /// Friendly name for the UI. Always absolute — never relative
    /// ("your country") — so the surface reads honestly when the
    /// user has multiple active jurisdictions.
    var displayName: String {
        switch self {
        case .unitedStates: "United States"
        case .canada: "Canada"
        }
    }

    /// SF Symbol paired with the name so Differentiate-Without-Color
    /// users still read the region correctly.
    var systemImage: String {
        switch self {
        case .unitedStates: "flag"
        case .canada: "leaf"
        }
    }

    // MARK: - Mapping

    /// Resolves a jurisdiction's country code to a supported region.
    /// Case-insensitive. Returns `nil` for jurisdictions the
    /// catalogue does not cover yet — the selector hides unknown
    /// regions rather than invent content.
    static func fromCountryCode(_ code: String) -> InvestingEducationRegion? {
        let normalized = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return allCases.first { $0.rawValue == normalized }
    }
}
