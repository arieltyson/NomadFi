// DecisionDraftInterpretation.swift
// NomadFi
//
// Pure value type that carries the structured fields an on-device
// interpreter extracted from a natural-language scenario. The
// intake review screen renders these into editable form fields
// before the user confirms a save into a real
// `DecisionDraftRecord`.
//
// Honesty contract pinned in `DecisionAIIntakeTests`:
//
//   • Interpretation is *structuring*, not analysis. The
//     interpreter never produces a recommendation, "best card",
//     "verified", or "analyzed" string.
//   • Every field on this type is optional except `scenarioText`
//     and `kind`. Fields the model could not pin down arrive as
//     `nil` and surface in `missingFields` so the review sheet can
//     ask the user to fill them in.
//   • `confidenceNote` is short, factual, and surfaces only when
//     the interpreter wants to flag an uncertain extraction. It is
//     never marketing copy.

import Foundation

/// Structured extraction output for a single natural-language
/// scenario. Built by `DecisionDraftInterpreter.interpret(...)`.
/// Mapped into a `DecisionDraftRecord` only after the user
/// reviews and confirms via `DecisionAIIntakeSheet`.
struct DecisionDraftInterpretation: Sendable, Equatable, Hashable {

    /// Best-effort decision kind. Always non-nil — the
    /// interpreter falls back to `.other` when uncertain rather
    /// than guessing across kinds.
    let kind: DecisionDraftKind

    /// Short title (≤ ~60 chars). `nil` when the model could not
    /// extract a clean one-line summary.
    let title: String?

    /// The natural-language scenario the user pasted in. Always
    /// non-empty — the interpreter rejects empty input upstream.
    let scenarioText: String

    /// Merchant or counterparty mentioned in the scenario, if any.
    let merchantName: String?

    /// City or short location hint, if any. Never a full address —
    /// the interpreter is instructed to keep this short.
    let locationText: String?

    /// Numeric amount, if the scenario implied one.
    let amount: Double?

    /// Currency for `amount`. `nil` when the model could not
    /// confidently pick one — surfaces as a missing field on the
    /// review sheet rather than defaulting silently.
    let currencyCode: CurrencyCode?

    /// Timing in the user's own words, if any.
    let timingText: String?

    /// Free-form notes the model surfaced (e.g. follow-ups the
    /// user might want to record). `nil` when nothing notable.
    let notes: String?

    /// Fields the model deliberately left blank. Surfaced on the
    /// review sheet so the user is the one who confirms the gap.
    let missingFields: [DecisionDraftInterpretationMissingField]

    /// Optional, factual one-line caveat from the interpreter.
    /// E.g. "Currency was inferred from the city." or "Amount
    /// could not be extracted from this scenario." Never marketing
    /// copy.
    let confidenceNote: String?
}

// MARK: - Field-wise builders

extension DecisionDraftInterpretation {

    /// Returns a copy with `kind` replaced. Used by the
    /// clarification loop in `DecisionAIIntakeViewModel` to fold a
    /// single answer into the pending interpretation without
    /// rebuilding every field by hand.
    func with(kind: DecisionDraftKind) -> DecisionDraftInterpretation {
        replacing(kind: kind)
    }

    func with(title: String?) -> DecisionDraftInterpretation {
        replacing(title: title)
    }

    func with(merchantName: String?) -> DecisionDraftInterpretation {
        replacing(merchantName: merchantName)
    }

    func with(locationText: String?) -> DecisionDraftInterpretation {
        replacing(locationText: locationText)
    }

    func with(amount: Double?) -> DecisionDraftInterpretation {
        replacing(amount: amount)
    }

    func with(currencyCode: CurrencyCode?) -> DecisionDraftInterpretation {
        replacing(currencyCode: currencyCode)
    }

    func with(timingText: String?) -> DecisionDraftInterpretation {
        replacing(timingText: timingText)
    }

    /// Single private constructor that all `with(...)` helpers
    /// route through. Keeps the field list authored exactly once
    /// so adding a new field cannot silently drop on copy.
    private func replacing(
        kind: DecisionDraftKind? = nil,
        title: String?? = nil,
        merchantName: String?? = nil,
        locationText: String?? = nil,
        amount: Double?? = nil,
        currencyCode: CurrencyCode?? = nil,
        timingText: String?? = nil
    ) -> DecisionDraftInterpretation {
        DecisionDraftInterpretation(
            kind: kind ?? self.kind,
            title: title ?? self.title,
            scenarioText: self.scenarioText,
            merchantName: merchantName ?? self.merchantName,
            locationText: locationText ?? self.locationText,
            amount: amount ?? self.amount,
            currencyCode: currencyCode ?? self.currencyCode,
            timingText: timingText ?? self.timingText,
            notes: self.notes,
            missingFields: self.missingFields,
            confidenceNote: self.confidenceNote
        )
    }
}
