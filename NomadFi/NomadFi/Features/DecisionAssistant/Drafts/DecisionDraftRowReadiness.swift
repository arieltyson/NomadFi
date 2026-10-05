// DecisionDraftRowReadiness.swift
// NomadFi
//
// Pure value-layer adapter that turns a captured draft (plus the
// existing `DecisionDraftEvaluator` output and the draft's
// lifecycle status) into the compact "what NomadFi can do now"
// badge the Decision Assistant draft list renders inline.
//
// Drafts v3 alignment contract:
//   • The persisted `DecisionDraftStatus` is *lifecycle* state.
//     The row badge is *readiness* state.
//   • Archived drafts always render their archived lifecycle —
//     readiness is a no-op for them.
//   • Active drafts render evaluator-derived readiness, never
//     the misleading bare "Needs engine" lifecycle label.
//   • Recommendation language is forbidden — readiness only
//     describes which deterministic engine NomadFi can hand off
//     to (or the next-step a user can take), never an outcome.
//
// Pure, deterministic, and test-pinned in
// `DecisionDraftRowReadinessTests`.

import Foundation

/// Discriminated union over the row badge for a single draft.
/// Built by `DecisionDraftRowReadiness.from(draft:accountSnapshot:)`
/// so the row stays purely presentational.
enum DecisionDraftRowReadiness: Sendable, Equatable, Hashable {

    /// Draft has been archived. Lifecycle wins over readiness; the
    /// row surfaces "Archived" regardless of what the evaluator
    /// would say.
    case archived

    /// Active draft whose captured fields are sufficient to hand
    /// off to one of NomadFi's deterministic engines (Purchase
    /// Card Check, Credit Timing).
    case engineReady

    /// Active draft whose engine handoff is blocked on a missing
    /// structured input (positive amount, saved credit card, …).
    case requiresContext(MissingContextField)

    /// Active draft whose closest source-backed surface is one of
    /// NomadFi's already-shipped Tools (Tax Vault,
    /// Investing Learn). Reminder-only — never a deep link.
    case routedToAdvancedTool(AdvancedToolDestination)

    /// Active draft whose kind has no deterministic engine yet.
    case noEngineYet

    /// Where a routed-to-advanced-tool draft points the user.
    enum AdvancedToolDestination: String, Sendable, Equatable, Hashable {
        case taxVault
        case investingLearn
    }

    // MARK: - Derivation

    /// Pure derivation from a draft + account snapshot. Lifecycle
    /// (archived) wins; otherwise the `DecisionDraftEvaluator`
    /// output drives the result.
    static func from(
        draft: DecisionDraftRecord,
        accountSnapshot: DecisionDraftAccountSnapshot = .empty
    ) -> DecisionDraftRowReadiness {
        if draft.status == .archived {
            return .archived
        }

        let evaluation = DecisionDraftEvaluator.evaluate(
            draft,
            accountSnapshot: accountSnapshot
        )

        switch evaluation.engineCoverage {
        case .engineReady:
            return .engineReady

        case .engineRequiresMoreContext:
            // Pull the missing field out of the evaluator's next
            // actions rather than re-deriving here, so a future
            // evaluator change automatically threads through.
            if let action = evaluation.nextActions.first(where: { action in
                if case .addContext = action { return true }
                return false
            }), case .addContext(let field) = action {
                return .requiresContext(field)
            }
            // Defensive fallback: the evaluator should always pair
            // `engineRequiresMoreContext` with at least one
            // `addContext` action. If that contract ever drifts,
            // fall back to a calm "no engine yet" state rather
            // than guessing.
            return .noEngineYet

        case .routedToAdvancedTool:
            return advancedToolReadiness(for: draft.kind) ?? .noEngineYet

        case .noEngineYet:
            return .noEngineYet
        }
    }

    private static func advancedToolReadiness(
        for kind: DecisionDraftKind
    ) -> DecisionDraftRowReadiness? {
        switch kind {
        case .taxEducation: .routedToAdvancedTool(.taxVault)
        case .investingEducation: .routedToAdvancedTool(.investingLearn)
        case .purchase, .travel, .creditTiming, .other:
            // Defensive — the evaluator only emits
            // `routedToAdvancedTool` for tax / investing kinds today.
            nil
        }
    }

    // MARK: - Display

    /// Short, factual label rendered on the row badge. Never uses
    /// recommendation, "best", "analyzed", or outcome language.
    var displayLabel: String {
        switch self {
        case .archived: "Archived"
        case .engineReady: "Engine ready"
        case .requiresContext(let field):
            switch field {
            case .amount: "Add amount first"
            case .currency: "Pick currency first"
            case .savedCreditCard: "Add a credit card first"
            }
        case .routedToAdvancedTool(let destination):
            switch destination {
            case .taxVault: "Review in Tax Vault"
            case .investingLearn: "Review in Investing Learn"
            }
        case .noEngineYet: "No engine yet"
        }
    }

    /// SF Symbol for the row badge.
    var systemImage: String {
        switch self {
        case .archived: "archivebox"
        case .engineReady: "checkmark.circle.fill"
        case .requiresContext: "questionmark.circle"
        case .routedToAdvancedTool(let destination):
            switch destination {
            case .taxVault: "doc.text.viewfinder"
            case .investingLearn: "books.vertical"
            }
        case .noEngineYet: "hourglass"
        }
    }

    /// Voice-friendly description rendered into the row's
    /// composed accessibility label. Procedural, never marketing.
    var accessibilityDescription: String {
        switch self {
        case .archived:
            "Archived draft."
        case .engineReady:
            "Engine ready. Open the draft to hand it to NomadFi's existing engine."
        case .requiresContext(let field):
            switch field {
            case .amount:
                "Engine handoff blocked. Add a positive amount on this draft first."
            case .currency:
                "Engine handoff blocked. Pick a currency on this draft first."
            case .savedCreditCard:
                "Engine handoff blocked. Add a credit card in Settings first."
            }
        case .routedToAdvancedTool(let destination):
            switch destination {
            case .taxVault:
                "No deterministic engine for this kind yet. The closest source-backed surface is Tax Vault."
            case .investingLearn:
                "No deterministic engine for this kind yet. The closest source-backed surface is Investing Learn."
            }
        case .noEngineYet:
            "Captured. NomadFi has no deterministic engine for this draft kind yet."
        }
    }

    // MARK: - Sorting

    /// Group ordering used by `DecisionDraftListPresentation`.
    /// Lower comes first.
    var sortGroupRank: Int {
        switch self {
        case .archived: 5
        case .engineReady: 0
        case .requiresContext: 1
        case .routedToAdvancedTool: 2
        case .noEngineYet: 3
        }
    }
}

