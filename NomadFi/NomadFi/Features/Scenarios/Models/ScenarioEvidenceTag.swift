// ScenarioEvidenceTag.swift
// NomadFi
//
// Evidence tag used on the Scenario Decision Brief. Each fact, payment
// option, or recommendation carries one of these so the UI never implies
// certainty about data that is really user input, inference, or from a
// source not yet re-verified against the current official page.

import Foundation

/// The evidence category of a scenario claim. Mapped from the citation
/// standard in `docs/README.md`.
enum ScenarioEvidenceTag: String, Codable, Sendable, CaseIterable, Equatable {
    /// A number or fact observed directly on a user-provided screenshot.
    case screenshotFact
    /// A value confirmed against a current official issuer, merchant, or
    /// regulator page.
    case officialSource
    /// A piece of information only the user can supply (available credit,
    /// statement date, Airbnb host policy, Wise balance, etc.).
    case needsUserInput
    /// Reasoning derived from the facts above. Never a factual claim on
    /// its own.
    case inference

    /// Short label suitable for a compact badge (≤ ~18 chars).
    var displayLabel: String {
        switch self {
        case .screenshotFact: "Screenshot"
        case .officialSource: "Official"
        case .needsUserInput: "Needs input"
        case .inference: "Inference"
        }
    }

    /// SF Symbol paired with the badge in compact UI.
    var systemImage: String {
        switch self {
        case .screenshotFact: "camera.viewfinder"
        case .officialSource: "checkmark.seal"
        case .needsUserInput: "person.crop.circle.badge.questionmark"
        case .inference: "sparkle.magnifyingglass"
        }
    }
}
