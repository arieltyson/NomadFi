// DecisionDraftInterpretationCompleteness.swift
// NomadFi
//
// Pure evaluator that answers "given this `DecisionDraftInterpretation`
// and its kind, which structured fields are genuinely missing?".
// Lives in its own file so the rule lives outside the interpreter
// (per Phase 9A follow-through) — the interpreter just *interprets*,
// the app decides what clarification is worth asking about.
//
// Honesty contract pinned in
// `DecisionDraftInterpretationCompletenessTests`:
//
//   • The output is a deduplicated, ordered list. Order matches
//     `DecisionDraftInterpretationMissingField.allCases` so the
//     review sheet and clarification planner render gaps in a
//     stable, predictable sequence.
//   • A field is "missing" only when it's both *required* for the
//     interpreted kind AND empty / unset on the interpretation.
//     Required-but-present and not-required-and-empty both count
//     as resolved.
//   • Pure — no SwiftData, no UI, no `@MainActor`. Test directly.

import Foundation

/// Pure evaluator that returns the kind-aware list of missing
/// structured fields for a given interpretation.
enum DecisionDraftInterpretationCompleteness {

    /// Returns the structured fields the user should be asked
    /// about, ordered by the canonical
    /// `DecisionDraftInterpretationMissingField.allCases`
    /// sequence so the UI surfaces them deterministically.
    static func missingFields(
        in interpretation: DecisionDraftInterpretation
    ) -> [DecisionDraftInterpretationMissingField] {
        let required = DecisionDraftKindCompleteness
            .requiredFields(for: interpretation.kind)
        guard !required.isEmpty else { return [] }

        return DecisionDraftInterpretationMissingField.allCases.filter { field in
            required.contains(field) && Self.isEmpty(field, in: interpretation)
        }
    }

    /// Whether the supplied interpretation lacks every required
    /// field for its kind. Used by the UI to short-circuit the
    /// review-sheet "no clarification needed" path.
    static func isComplete(
        _ interpretation: DecisionDraftInterpretation
    ) -> Bool {
        missingFields(in: interpretation).isEmpty
    }

    // MARK: - Private

    /// True when the supplied field carries no usable value on the
    /// interpretation. Empty strings, nil, and non-positive amounts
    /// all count as missing — the same rule the persistence mapper
    /// uses for "the user did not enter this".
    private static func isEmpty(
        _ field: DecisionDraftInterpretationMissingField,
        in interpretation: DecisionDraftInterpretation
    ) -> Bool {
        switch field {
        case .kind:
            // Kind is non-optional on the interpretation type —
            // there is no empty case, only `.other` as the
            // conservative fallback. Treat `.other` as missing only
            // when the kind itself is required (none of the kinds
            // currently require it, but the predicate is honest).
            return interpretation.kind == .other
        case .title:
            return interpretation.title.isNilOrBlank
        case .merchantName:
            return interpretation.merchantName.isNilOrBlank
        case .locationText:
            return interpretation.locationText.isNilOrBlank
        case .amount:
            guard let amount = interpretation.amount else { return true }
            return amount <= 0
        case .currencyCode:
            return interpretation.currencyCode == nil
        case .timingText:
            return interpretation.timingText.isNilOrBlank
        }
    }
}

private extension Optional where Wrapped == String {
    /// `true` when the optional is nil or — once unwrapped —
    /// trims to an empty string.
    var isNilOrBlank: Bool {
        switch self {
        case .none:
            return true
        case .some(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
