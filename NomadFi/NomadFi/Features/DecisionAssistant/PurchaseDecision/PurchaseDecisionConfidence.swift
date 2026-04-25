// PurchaseDecisionConfidence.swift
// NomadFi
//
// Deterministic, source-aware confidence label for the generic
// purchase engine's recommendation. Phase 3 + `docs/MISSION.md`
// both call for explicit source confidence / freshness — this
// type is how that surfaces on the brief, the dialog layer, and
// the future App Intent surface.
//
// Honesty contract:
//   • Confidence reflects *the recommendation's evidence*, not the
//     user's life situation.
//   • Confidence is never used to escalate marketing language. A
//     `.high` recommendation is still NomadFi's deterministic best
//     pick from the saved inputs — never "the best card".
//   • The explanation list is a frozen factual list, not a
//     persuasive sentence. Each entry stays short and procedural.

import Foundation

/// Three-tier confidence label, ordered from least to most
/// trustworthy. Pure value type so tests can pin the derivation
/// rules and the brief view can render the badge directly.
enum PurchaseDecisionConfidence: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable, Comparable {

    /// At least one major signal is unverified or missing — for
    /// example FX terms unverified on a cross-currency purchase, or
    /// the engine could not pick a recommendation. The brief still
    /// renders the candidate set, but the surface treats the pick
    /// as provisional.
    case lowOrUnverified

    /// A recommendation exists and clears the hard guardrails, but
    /// at least one soft caveat applies (cross-currency with a
    /// verified FX fee, travel signal, outstanding checks, etc.).
    case moderate

    /// Recommendation exists, currency matches, FX is not a
    /// concern, no outstanding checks, no travel signal.
    case high

    var id: String { rawValue }

    /// Strict ordering (`.lowOrUnverified < .moderate < .high`) so
    /// callers can compare confidences without re-mapping the enum.
    static func < (
        lhs: PurchaseDecisionConfidence,
        rhs: PurchaseDecisionConfidence
    ) -> Bool {
        rank(lhs) < rank(rhs)
    }

    private static func rank(_ value: PurchaseDecisionConfidence) -> Int {
        switch value {
        case .lowOrUnverified: 0
        case .moderate: 1
        case .high: 2
        }
    }

    // MARK: - Display

    /// User-facing label rendered on the brief. Never marketing-y;
    /// the wording matches the regulator hierarchy in
    /// `docs/README.md`'s evidence levels.
    var displayLabel: String {
        switch self {
        case .lowOrUnverified: "Low / unverified"
        case .moderate: "Moderate"
        case .high: "High"
        }
    }

    /// SF Symbol paired with the badge. Avoids any traffic-light
    /// red/yellow/green metaphor that would imply a regulator-grade
    /// rating.
    var systemImage: String {
        switch self {
        case .lowOrUnverified: "questionmark.diamond"
        case .moderate: "scale.3d"
        case .high: "checkmark.seal"
        }
    }

    /// Procedural one-line description. Read out by the dialog
    /// layer and rendered as a tooltip / footnote on the brief.
    var summary: String {
        switch self {
        case .lowOrUnverified:
            "NomadFi cannot stand behind the recommendation strongly. Verify the inputs the brief lists before committing."
        case .moderate:
            "NomadFi has a recommendation but at least one soft caveat applies. Read the rationale before committing."
        case .high:
            "NomadFi's recommendation rests on inputs that match the purchase currency and have no outstanding checks. Verify rates against your issuer's current page when in doubt."
        }
    }
}
