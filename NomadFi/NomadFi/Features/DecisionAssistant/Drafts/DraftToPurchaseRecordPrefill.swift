// DraftToPurchaseRecordPrefill.swift
// NomadFi
//
// Phase 1 follow-through — pure prefill helper that copies a
// captured draft's structured fields into the singleton
// `PurchaseDecisionRecord` so the user can hand a draft to the
// existing Purchase Card Check engine.
//
// Honesty contract pinned in `DraftToPurchaseRecordPrefillTests`:
//
//   • Prefill is *strictly user-invoked* — this helper never runs
//     unless a handoff button is tapped.
//   • The draft itself is never mutated and never has its status
//     flipped to "analyzed". Drafts stay `.needsEngine` regardless
//     of what the user does in the prefilled brief.
//   • Empty / nil draft fields do not overwrite existing record
//     fields. The user's last typed brief input wins when the
//     draft has nothing to contribute.
//   • Travel drafts pick the `.travel` merchant category. Generic
//     purchase drafts default to `.general` and let the user
//     refine in the brief picker.

import Foundation

/// Pure namespace that copies a draft's structured fields into a
/// `PurchaseDecisionRecord`.
enum DraftToPurchaseRecordPrefill {

    /// Mutates `record` in place with the draft's structured
    /// fields and stamps `updatedAt`. Returns nothing — the caller
    /// already owns the live record reference.
    @MainActor
    static func apply(
        draft: DecisionDraftRecord,
        into record: PurchaseDecisionRecord,
        now: Date = .now
    ) {
        let trimmedMerchant = draft.merchantName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMerchant.isEmpty {
            record.merchantName = trimmedMerchant
        }

        let trimmedLocation = draft.locationText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLocation.isEmpty {
            // `PurchaseDecisionRecord.countryCode` is the historical
            // location-hint storage field — see PurchaseContext for
            // the naming rationale.
            record.countryCode = trimmedLocation
        }

        let trimmedTiming = draft.timingText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTiming.isEmpty {
            record.timingText = trimmedTiming
        }

        if let amount = draft.amount, amount > 0 {
            record.amount = amount
        }

        record.currencyCodeRawValue = draft.currencyCode.rawValue
        record.categoryRawValue = mapCategory(for: draft.kind).rawValue
        record.updatedAt = now
    }

    /// Maps a draft kind to the Purchase Decision engine's
    /// `MerchantCategory`. Travel drafts pick `.travel` so the
    /// existing engine fires its travel-aware confidence path
    /// without further user input.
    static func mapCategory(
        for kind: DecisionDraftKind
    ) -> MerchantCategory {
        switch kind {
        case .travel: .travel
        case .purchase: .general
        case .creditTiming, .taxEducation, .investingEducation, .other:
            // Defensive default — these kinds never call the
            // purchase prefill, but keep the mapping total.
            .general
        }
    }
}
