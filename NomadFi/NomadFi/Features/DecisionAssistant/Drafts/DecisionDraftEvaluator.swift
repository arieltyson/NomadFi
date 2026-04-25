// DecisionDraftEvaluator.swift
// NomadFi
//
// Phase 1 follow-through — pure, deterministic evaluator that turns
// a captured `DecisionDraftRecord` plus a small account snapshot
// into a `DecisionDraftEvaluation`. Never mutates the draft, never
// changes its persisted `DecisionDraftStatus`, never auto-analyzes.
//
// Honesty contract pinned in `DecisionDraftEvaluatorTests`:
//
//   • Drafts are never auto-analyzed by this evaluator. The output
//     is a *description* of what NomadFi can do if the user opts
//     in by tapping a handoff button on the detail view.
//   • Recommendation language is forbidden in the headline + action
//     labels. Recommendations belong to the engines themselves.
//   • Tax and Investing drafts never deep-link cross-tab — the
//     evaluator emits a calm "Review in Tax Vault / Investing
//     Learn" reminder only.
//   • An `.other` kind never produces a fake handoff. It returns a
//     factual `noEngineYet` action.
//   • Purchase / Travel drafts route to the Purchase Card Check
//     engine only when the captured fields are sufficient
//     (positive amount). Otherwise the evaluator emits an
//     `addContext` reminder and the route stays disabled.
//   • Credit-timing drafts route to the Credit Timing brief only
//     when the user has at least one credit card on file.

import Foundation

/// Pure namespace that derives a `DecisionDraftEvaluation` for a
/// captured draft.
enum DecisionDraftEvaluator {

    // MARK: - Public API

    /// Returns the deterministic evaluation for the given draft and
    /// account snapshot. Pure over its inputs.
    static func evaluate(
        _ draft: DecisionDraftRecord,
        accountSnapshot: DecisionDraftAccountSnapshot = .empty
    ) -> DecisionDraftEvaluation {
        switch draft.kind {
        case .purchase:
            return evaluatePurchase(draft, isTravelKind: false)
        case .travel:
            return evaluatePurchase(draft, isTravelKind: true)
        case .creditTiming:
            return evaluateCreditTiming(snapshot: accountSnapshot)
        case .taxEducation:
            return evaluateTaxEducation()
        case .investingEducation:
            return evaluateInvestingEducation()
        case .other:
            return evaluateOther()
        }
    }

    // MARK: - Purchase / Travel

    private static func evaluatePurchase(
        _ draft: DecisionDraftRecord,
        isTravelKind: Bool
    ) -> DecisionDraftEvaluation {
        var missing: [String] = []
        if (draft.amount ?? 0) <= 0 {
            missing.append("amount")
        }

        if missing.isEmpty {
            let headline = isTravelKind
                ? "NomadFi can hand this travel draft to the existing Purchase Card Check, prefilled from what you captured."
                : "NomadFi can hand this purchase draft to the existing Purchase Card Check, prefilled from what you captured."
            return DecisionDraftEvaluation(
                engineCoverage: .engineReady,
                headline: headline,
                nextActions: [.openPurchaseCheck]
            )
        }

        var actions: [DecisionDraftNextAction] = []
        if missing.contains("amount") {
            actions.append(.addContext(field: .amount))
        }
        let headline = isTravelKind
            ? "Add a positive amount on this travel draft so NomadFi can hand it to the Purchase Card Check engine."
            : "Add a positive amount on this purchase draft so NomadFi can hand it to the Purchase Card Check engine."
        return DecisionDraftEvaluation(
            engineCoverage: .engineRequiresMoreContext(missing: missing),
            headline: headline,
            nextActions: actions
        )
    }

    // MARK: - Credit timing

    private static func evaluateCreditTiming(
        snapshot: DecisionDraftAccountSnapshot
    ) -> DecisionDraftEvaluation {
        if snapshot.hasAnyCreditCard {
            return DecisionDraftEvaluation(
                engineCoverage: .engineReady,
                headline: "NomadFi can open the existing Credit Timing Check against your saved credit cards.",
                nextActions: [.openCreditTimingCheck]
            )
        }
        return DecisionDraftEvaluation(
            engineCoverage: .engineRequiresMoreContext(missing: ["savedCreditCard"]),
            headline: "NomadFi has no credit card on file yet. Add one in Settings before opening the Credit Timing Check.",
            nextActions: [.addContext(field: .savedCreditCard)]
        )
    }

    // MARK: - Tax / Investing learn

    private static func evaluateTaxEducation() -> DecisionDraftEvaluation {
        DecisionDraftEvaluation(
            engineCoverage: .routedToAdvancedTool,
            headline: "NomadFi does not yet have a deterministic engine for tax-education drafts. The closest source-backed surface is Tax Vault.",
            nextActions: [.reviewInTaxVault]
        )
    }

    private static func evaluateInvestingEducation() -> DecisionDraftEvaluation {
        DecisionDraftEvaluation(
            engineCoverage: .routedToAdvancedTool,
            headline: "NomadFi does not yet have a deterministic engine for investing-learning drafts. The closest source-backed surface is Investing Learn.",
            nextActions: [.reviewInInvestingLearn]
        )
    }

    // MARK: - Other

    private static func evaluateOther() -> DecisionDraftEvaluation {
        DecisionDraftEvaluation(
            engineCoverage: .noEngineYet,
            headline: "NomadFi has captured this draft on this device. No deterministic engine fits the Other kind today — that's deliberate.",
            nextActions: [.noEngineYet]
        )
    }
}
