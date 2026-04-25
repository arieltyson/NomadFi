// DecisionDraftInterpretationMapper.swift
// NomadFi
//
// Pure namespace that turns a user-confirmed
// `DecisionDraftInterpretation` into a fresh `DecisionDraftRecord`.
// Called by `DecisionAIIntakeViewModel` only after the user
// reviews the extracted fields on the intake sheet — the mapper
// itself never persists anything; persistence is the caller's job
// via `modelContext.insert(...)`.
//
// Honesty contract:
//   • The new record is always inserted with status
//     `.needsEngine`. The mapper never marks anything "analyzed".
//   • All trimming happens here so the persisted record matches
//     `DecisionDraftStore.insertDraft`'s rules without forking
//     trimming logic.
//   • Empty / nil interpretation fields land as empty strings on
//     the record (matching the model's existing defaults), so the
//     evaluator's downstream `addContext` reminders fire normally.

import Foundation

enum DecisionDraftInterpretationMapper {

    /// Builds a fresh `DecisionDraftRecord` from a user-confirmed
    /// interpretation. Pure — no `ModelContext`, no insert. The
    /// caller persists by inserting the returned record into a
    /// context.
    static func record(
        from interpretation: DecisionDraftInterpretation,
        now: Date = .now
    ) -> DecisionDraftRecord {
        DecisionDraftRecord(
            title: trimmedOrEmpty(interpretation.title),
            scenarioText: interpretation.scenarioText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            kind: interpretation.kind,
            merchantName: trimmedOrEmpty(interpretation.merchantName),
            locationText: trimmedOrEmpty(interpretation.locationText),
            amount: positiveOrNil(interpretation.amount),
            currencyCode: interpretation.currencyCode ?? .usd,
            timingText: trimmedOrEmpty(interpretation.timingText),
            notes: trimmedOrEmpty(interpretation.notes),
            status: .needsEngine,
            createdAt: now,
            updatedAt: now
        )
    }

    // MARK: - Helpers

    private static func trimmedOrEmpty(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func positiveOrNil(_ amount: Double?) -> Double? {
        guard let amount, amount > 0 else { return nil }
        return amount
    }
}
