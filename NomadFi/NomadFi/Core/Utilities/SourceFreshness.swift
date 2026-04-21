// SourceFreshness.swift
// NomadFi
//
// Pure, testable freshness policy derived from the windows documented in
// `docs/README.md`. Does no I/O and has no SwiftUI or SwiftData
// dependencies so it can be exercised directly from unit tests.

import Foundation

/// The category of data whose freshness is being evaluated. Mapped to the
/// re-verification windows in `docs/README.md`.
enum SourceDataDomain: Sendable, Equatable {
    case liveFXMarketData
    case issuerCardTerms
    case taxResidencyRules
    case creditScoreGuidance
    case depositInsuranceLimits
    case academicResearch
}

/// The result of a freshness check.
///
/// - `fresh`: the source was verified within its domain's allowed window.
/// - `stale`: the source has a verification date but it is outside the window.
/// - `unknown`: there is no verification date — **must not** be treated as fresh.
enum FreshnessStatus: Sendable, Equatable {
    case fresh
    case stale
    case unknown
}

/// Evaluates whether cached source data is fresh enough to drive a
/// recommendation, given the freshness windows documented in
/// `docs/README.md`.
enum SourceFreshness {

    /// Maximum acceptable age for a given data domain, in seconds.
    ///
    /// - Tax and residency rules intentionally return `nil`: they are
    ///   re-verified against the current tax year, not a rolling window.
    ///   Callers must check the tax year themselves.
    static func allowedAge(for domain: SourceDataDomain) -> TimeInterval? {
        switch domain {
        case .liveFXMarketData:
            // Dashboard cache is 1 hour. Indicative only — still label.
            60 * 60
        case .issuerCardTerms:
            // ~30 days; issuer terms are the floor for money-impacting claims.
            60 * 60 * 24 * 30
        case .creditScoreGuidance:
            // Quarterly review per docs/README.md.
            60 * 60 * 24 * 90
        case .depositInsuranceLimits:
            // Annual verification.
            60 * 60 * 24 * 365
        case .academicResearch:
            // Academic citations reference publication date; no rolling window.
            nil
        case .taxResidencyRules:
            // Re-verify against the current tax year, not a rolling window.
            nil
        }
    }

    /// Returns the freshness status for a verification timestamp within a
    /// given domain.
    ///
    /// - Parameters:
    ///   - verifiedAt: When the source was last verified or accessed.
    ///     `nil` resolves to `.unknown` — never `.fresh`.
    ///   - domain: The data domain being evaluated.
    ///   - now: Reference "now" date. Injected for deterministic tests.
    static func status(
        verifiedAt: Date?,
        domain: SourceDataDomain,
        now: Date = .now
    ) -> FreshnessStatus {
        guard let verifiedAt else { return .unknown }
        guard let allowed = allowedAge(for: domain) else {
            // No rolling window defined for this domain — we can report
            // whether a timestamp exists, but not whether it is current.
            return .unknown
        }
        let age = now.timeIntervalSince(verifiedAt)
        return age <= allowed ? .fresh : .stale
    }

    /// Convenience overload that pulls the verification timestamp from a
    /// ``SourceProvenance`` value.
    static func status(
        for provenance: SourceProvenance,
        domain: SourceDataDomain,
        now: Date = .now
    ) -> FreshnessStatus {
        status(verifiedAt: provenance.accessedAt, domain: domain, now: now)
    }

    /// Returns the confidence a caller should actually present to the user
    /// after accounting for freshness.
    ///
    /// The goal is that a label only says "Verified" when the underlying
    /// source is verified *and* was checked inside the domain's allowed
    /// window. Stale or unknown-age verified sources are downgraded so
    /// the UI can caveat them.
    ///
    /// Non-verified confidence values pass through unchanged — an
    /// `.indicative` or `.userProvided` source does not become more
    /// reliable by being "fresh".
    static func effectiveConfidence(
        for provenance: SourceProvenance,
        domain: SourceDataDomain,
        now: Date = .now
    ) -> SourceConfidence {
        guard provenance.confidence.isVerified else {
            return provenance.confidence
        }
        switch status(for: provenance, domain: domain, now: now) {
        case .fresh: return provenance.confidence
        case .stale, .unknown: return .unverified
        }
    }
}
