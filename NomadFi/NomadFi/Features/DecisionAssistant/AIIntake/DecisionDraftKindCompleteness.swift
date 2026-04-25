// DecisionDraftKindCompleteness.swift
// NomadFi
//
// Pure rules that decide which structured fields a freshly
// extracted `DecisionDraftInterpretation` is *required* to carry,
// keyed by the interpreted `DecisionDraftKind`. Lives in its own
// file so the rules are unit-testable without spinning up
// SwiftData, the interpreter, or any UI.
//
// Honesty contract pinned in `DecisionDraftKindCompletenessTests`:
//
//   • The set is *required*, not "would be nice". Asking the user
//     about an optional field is friction; the only justification
//     for a clarifying question is that a deterministic engine
//     downstream cannot proceed without that field.
//   • Non-purchase kinds never demand purchase-shaped fields.
//     `taxEducation`, `investingEducation`, and `creditTiming` ask
//     for amount / currency / merchant only when the kind itself
//     genuinely needs them.
//   • `other` stays conservative — no required fields. The user
//     captured something NomadFi has no engine for; we don't
//     pretend we know what's missing.
//
// Per Apple's Generative AI HIG: "ask before significant actions"
// and "keep people in control" — so the rules below err on the
// side of *fewer* clarifying questions. A clarifying question is
// only earned when the deterministic engine truly cannot run
// without the answer.

import Foundation

/// Pure namespace listing the required structured fields per
/// `DecisionDraftKind`. The clarification planner uses this to
/// decide which gaps in an interpretation are worth asking about.
enum DecisionDraftKindCompleteness {

    /// Structured fields a downstream deterministic engine genuinely
    /// requires for the given `kind`. Returned as a `Set` so callers
    /// can intersect with the model's missing-field list cheaply.
    static func requiredFields(
        for kind: DecisionDraftKind
    ) -> Set<DecisionDraftInterpretationMissingField> {
        switch kind {
        case .purchase, .travel:
            // Purchase Card Check / Wise FX engines need an amount
            // (otherwise the projection is meaningless) and a
            // currency (otherwise FX is undefined). Merchant and
            // location are *helpful* but not blocking — many real
            // purchases have a merchant the user can fill in later.
            return [.amount, .currencyCode]
        case .creditTiming:
            // Credit Timing is account-driven: the user picks a
            // saved card on the brief itself. The intake captures
            // the scenario in words; merchant / amount / currency
            // are not required up front.
            return []
        case .taxEducation, .investingEducation:
            // Education kinds route to the Tax Vault / Investing
            // Learn surfaces where the user reads source-backed
            // lessons. There is nothing for a clarifying question
            // to unlock — we never demand purchase-shaped fields.
            return []
        case .other:
            // Conservative default. The user captured something
            // NomadFi has no engine for; clarifying questions about
            // shape would only add friction.
            return []
        }
    }
}
