// DecisionDraftKindAppEnum.swift
// NomadFi
//
// App Intents-facing adapter for ``DecisionDraftKind``. Kept separate
// from the core model so ``DecisionDraftKind`` never has to import
// `AppIntents` — the core decision domain stays UI- and
// framework-free, and the intent layer carries its own
// `AppEnum`-conforming mirror.
//
// One-to-one mapping with ``DecisionDraftKind`` so any future kind
// added to the core enum requires a symmetric case here; Swift's
// exhaustive switching keeps that contract honest.

import AppIntents

/// App Intents adapter for the user-chosen decision-draft category.
///
/// Surfaces the same six kinds as ``DecisionDraftKind`` inside Siri
/// and the Shortcuts app, carrying the display labels through so the
/// spoken picker reads naturally ("Credit timing", "Tax & education"),
/// not the raw enum identifiers.
enum DecisionDraftKindAppEnum: String, AppEnum {

    case purchase
    case creditTiming
    case travel
    case taxEducation
    case investingEducation
    case other

    // MARK: - AppEnum

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        "Decision kind"

    static let caseDisplayRepresentations: [DecisionDraftKindAppEnum: DisplayRepresentation] = [
        .purchase: "Purchase",
        .creditTiming: "Credit timing",
        .travel: "Travel",
        .taxEducation: "Tax & education",
        .investingEducation: "Investing & learning",
        .other: "Other",
    ]
}

// MARK: - Bridging

extension DecisionDraftKindAppEnum {

    /// Maps the App Intents adapter back to the core model enum.
    /// Exhaustive by construction so adding a case to either enum
    /// fails the build at this boundary until both sides agree.
    var draftKind: DecisionDraftKind {
        switch self {
        case .purchase: .purchase
        case .creditTiming: .creditTiming
        case .travel: .travel
        case .taxEducation: .taxEducation
        case .investingEducation: .investingEducation
        case .other: .other
        }
    }

    /// Mirror constructor — lets callers translate a core kind into
    /// an intent-facing kind when pre-seeding parameters from saved
    /// state in a future intake flow.
    init(_ kind: DecisionDraftKind) {
        switch kind {
        case .purchase: self = .purchase
        case .creditTiming: self = .creditTiming
        case .travel: self = .travel
        case .taxEducation: self = .taxEducation
        case .investingEducation: self = .investingEducation
        case .other: self = .other
        }
    }
}
