// SourceProvenance.swift
// NomadFi
//
// Lightweight value types that let recommendation-facing data carry a
// confidence label, source identity, and jurisdiction scope at runtime.
// The shape follows the citation standard defined in `docs/README.md`.

import Foundation

/// How much weight a recommendation should give to a piece of data,
/// mapped from the evidence hierarchy in `docs/README.md`.
enum SourceConfidence: String, Codable, Sendable, CaseIterable, Equatable {
    case userProvided
    case verifiedPrimary
    case verifiedSecondary
    case institutional
    case peerReviewed
    case indicative
    case unverified

    /// Short, user-facing label suitable for a compact badge.
    /// Phrased so that unverified or indicative data never reads as certain.
    var displayLabel: String {
        switch self {
        case .userProvided: "User provided"
        case .verifiedPrimary: "Verified"
        case .verifiedSecondary: "Verified"
        case .institutional: "Institutional"
        case .peerReviewed: "Peer reviewed"
        case .indicative: "Indicative"
        case .unverified: "Unverified"
        }
    }

    /// `true` when the source is an official primary or secondary
    /// disclosure and can be presented to the user as verified.
    var isVerified: Bool {
        switch self {
        case .verifiedPrimary, .verifiedSecondary: true
        case .userProvided, .institutional, .peerReviewed, .indicative, .unverified: false
        }
    }
}

/// The kind of source backing a claim. Used for citation rendering and
/// for UI decisions that depend on source category rather than confidence.
enum SourceType: String, Codable, Sendable, CaseIterable, Equatable {
    case issuerDisclosure
    case centralBankDataset
    case regulatorGuidance
    case depositInsurer
    case taxAuthority
    case networkRateCalculator
    case peerReviewedResearch
    case institutionalResearch
    case prototypeAPI
    case sampleData
    case userEntered
    case unknown
}

/// Geographic scope a source applies to.
enum JurisdictionScope: String, Codable, Sendable, CaseIterable, Equatable {
    case unitedStates
    case canada
    case trinidadAndTobago
    case crossBorder
    case unknown

    /// Maps an ISO-style country code (as stored on `Account.jurisdiction`
    /// and `Transaction.jurisdiction`) into a scope. Case-insensitive.
    /// Empty or unrecognized inputs resolve to ``unknown``.
    init(countryCode: String?) {
        guard let countryCode, !countryCode.isEmpty else {
            self = .unknown
            return
        }
        switch countryCode.uppercased() {
        case "US", "USA": self = .unitedStates
        case "CA", "CAN": self = .canada
        case "TT", "TTO": self = .trinidadAndTobago
        default: self = .unknown
        }
    }
}

/// Provenance metadata attached to any value used in a money-impacting
/// recommendation. Every field is optional except `confidence` so a
/// caller can emit a minimally useful label without fabricating details.
struct SourceProvenance: Codable, Sendable, Equatable {
    var name: String
    var urlString: String?
    var type: SourceType
    var confidence: SourceConfidence
    var jurisdiction: JurisdictionScope
    var accessedAt: Date?
    var publishedAt: Date?
    var notes: String?

    init(
        name: String,
        urlString: String? = nil,
        type: SourceType,
        confidence: SourceConfidence,
        jurisdiction: JurisdictionScope = .unknown,
        accessedAt: Date? = nil,
        publishedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.urlString = urlString
        self.type = type
        self.confidence = confidence
        self.jurisdiction = jurisdiction
        self.accessedAt = accessedAt
        self.publishedAt = publishedAt
        self.notes = notes
    }
}

// MARK: - Stock Provenance

extension SourceProvenance {

    /// Provenance for the prototype open exchange-rate API currently wired
    /// into `LiveExchangeRateService`. Classified as indicative per the
    /// evidence hierarchy in `docs/README.md` — never present it as official.
    static func openExchangeRatesAPI(accessedAt: Date) -> SourceProvenance {
        SourceProvenance(
            name: "open.er-api.com",
            urlString: "https://open.er-api.com/v6/latest/",
            type: .prototypeAPI,
            confidence: .indicative,
            jurisdiction: .crossBorder,
            accessedAt: accessedAt,
            notes: "Free public exchange-rate API used for prototype display only."
        )
    }

    /// Provenance for deterministic mock/sample rates used in previews and
    /// tests. Never surfaced to real users as a money-impacting claim.
    static func sampleRates(accessedAt: Date) -> SourceProvenance {
        SourceProvenance(
            name: "NomadFi sample data",
            urlString: nil,
            type: .sampleData,
            confidence: .indicative,
            jurisdiction: .crossBorder,
            accessedAt: accessedAt,
            notes: "Deterministic preview data; not a live market rate."
        )
    }

    /// Provenance for account fee values entered by the user without a
    /// citable issuer disclosure. Treated as `userProvided`, never verified.
    static func userEnteredAccountFee(accessedAt: Date? = nil) -> SourceProvenance {
        SourceProvenance(
            name: "User-entered value",
            urlString: nil,
            type: .userEntered,
            confidence: .userProvided,
            jurisdiction: .unknown,
            accessedAt: accessedAt,
            notes: "Fee entered manually; not verified against issuer disclosure."
        )
    }
}
