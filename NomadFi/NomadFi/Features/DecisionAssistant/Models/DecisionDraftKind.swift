// DecisionDraftKind.swift
// NomadFi
//
// Pure, Sendable categorisation for a user-captured decision draft.
// Kept in its own file so the Decision Assistant form, detail, and
// row renderers all read from a single source of truth for labels
// and SF Symbols.
//
// This type is intentionally shallow — NomadFi is not running a
// classification model on drafts yet, and it will not invent a kind
// on the user's behalf. The user picks exactly one kind at capture
// time; future deterministic engines can filter drafts by kind when
// they ship.

import Foundation

/// User-chosen category for a captured decision draft.
///
/// Each case maps to a future deterministic engine (or to the
/// `.other` bucket if nothing deterministic exists yet). Persisted by
/// ``DecisionDraftRecord/kindRawValue``.
enum DecisionDraftKind: String, CaseIterable, Codable, Hashable, Sendable {

    /// A cross-border purchase, matching the shape of the existing
    /// Amazon arrival-order scenario.
    case purchase

    /// A credit-card timing decision — pay-before-close, utilization,
    /// statement close window. Sibling to Phase 6 in the roadmap.
    case creditTiming

    /// A travel-mode decision — rail, fee, acceptance, and jurisdiction.
    case travel

    /// A tax-education or residency-context question.
    case taxEducation

    /// An investing-education question — index funds, risk, fit.
    case investingEducation

    /// Anything the user wants to capture that doesn't fit the above.
    case other

    // MARK: - Display

    /// User-facing label used in pickers and draft rows.
    var displayLabel: String {
        switch self {
        case .purchase: "Purchase"
        case .creditTiming: "Credit timing"
        case .travel: "Travel"
        case .taxEducation: "Tax & education"
        case .investingEducation: "Investing & learning"
        case .other: "Other"
        }
    }

    /// SF Symbol name paired with the label in lists.
    var systemImage: String {
        switch self {
        case .purchase: "cart.fill"
        case .creditTiming: "calendar.badge.clock"
        case .travel: "airplane"
        case .taxEducation: "doc.text.magnifyingglass"
        case .investingEducation: "chart.line.uptrend.xyaxis"
        case .other: "square.stack.3d.up"
        }
    }

    /// VoiceOver-friendly description — read out when a draft is
    /// focused so users hear the kind without guessing from the icon.
    var accessibilityLabel: String {
        switch self {
        case .purchase: "Purchase decision"
        case .creditTiming: "Credit timing decision"
        case .travel: "Travel decision"
        case .taxEducation: "Tax or education decision"
        case .investingEducation: "Investing or learning decision"
        case .other: "Other decision"
        }
    }
}
