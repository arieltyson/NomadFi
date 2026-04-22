// DecisionAssistantIntentDialog.swift
// NomadFi
//
// Pure, testable dialog builders for every Siri / App Shortcut entry
// point into the Decision Assistant. Keeping this logic here (instead
// of inside an `AppIntent.perform()`) lets tests assert that NomadFi's
// voice surface stays honest — no FX-fee-only answers, no invented
// recommendations when user inputs are missing, no "verified" framing
// the deterministic engine does not support.
//
// The formatters accept already-computed `ScenarioDecision` values so
// they never reach into SwiftData or `AppIntents`. That keeps them
// trivially testable and keeps dialog copy reviewable as code.

import Foundation

/// Collection of pure dialog builders for the Decision Assistant's
/// voice / Shortcuts surface. All strings are deterministic functions
/// of their inputs.
enum DecisionAssistantIntentDialog {

    // MARK: - Inputs

    /// Minimum context the formatters need about a scenario brief.
    /// Packaged as a value type so tests don't need a live view model.
    struct ScenarioBriefContext: Sendable, Equatable {

        /// The engine's deterministic output for the scenario.
        let decision: ScenarioDecision

        /// Whether the user has supplied any meaningful input to the
        /// record backing this decision. Mirrors the interaction flag
        /// on `DecisionAssistantViewModel` but is computed up-front so
        /// the formatter stays SwiftData-free.
        let hasInteractedWithInputs: Bool
    }

    // MARK: - "Which card?" (rewritten ActiveCardIntent)

    /// Dialog for the legacy "Which card should I use?" phrase.
    ///
    /// The old version answered with the lowest-foreign-transaction-fee
    /// account regardless of scenario — an FX-only heuristic the app
    /// no longer stands behind. The new copy is explicit: right now
    /// NomadFi can only answer the Amazon arrival-order decision with a
    /// source-backed recommendation, and it defers to the Scenario 1
    /// engine rather than inventing a generic ranking.
    static func whichCardAnswer(
        brief: ScenarioBriefContext
    ) -> String {
        let preamble = "NomadFi can't yet answer which card to use for any merchant. "
            + "Right now the deterministic engine only covers your Amazon arrival order."
        return preamble + " " + amazonArrivalReviewSentence(brief: brief)
    }

    // MARK: - "Review my Amazon order"

    /// Dialog for the "Review my Amazon order" / voice review path.
    ///
    /// Returns a concise sentence carrying the current engine ruling
    /// and a check-count summary, always followed by an explicit
    /// pointer to finish the decision inside the app. Never claims a
    /// recommendation when the engine has none.
    static func amazonArrivalReview(
        brief: ScenarioBriefContext
    ) -> String {
        amazonArrivalReviewSentence(brief: brief)
    }

    // MARK: - "Continue my payment decision"

    /// Dialog for the "Continue my payment decision" path, which also
    /// opens the app. Intentionally short — the app-side brief is the
    /// surface the user is about to see, so the dialog just sets the
    /// scene and names the ruling.
    static func continueAmazonArrivalDecision(
        brief: ScenarioBriefContext
    ) -> String {
        if !brief.hasInteractedWithInputs {
            return "Opening NomadFi to your Amazon arrival decision. "
                + "You'll need to enter your cart, Chase, and Wise details before the engine can pick a payment path."
        }

        let outstanding = brief.decision.outstandingChecks.count
        if outstanding == 0 {
            return "Opening your Amazon arrival decision in NomadFi. \(brief.decision.ruling)"
        }

        let checkPhrase = formattedCheckCount(outstanding)
        return "Opening your Amazon arrival decision in NomadFi. "
            + "\(brief.decision.ruling) \(checkPhrase) outstanding."
    }

    // MARK: - "Open Decision Assistant"

    /// Dialog for the plain "Open the Decision Assistant" path. Does
    /// not run the engine — it's a pure navigation affordance — but
    /// stays honest about the current catalog so the spoken feedback
    /// matches what the user will see on-screen.
    static let openDecisionAssistant: String =
        "Opening your Decision Assistant in NomadFi. Today it covers your Amazon arrival order; more decisions land as the deterministic engines do."

    // MARK: - Helpers

    /// Core sentence shared by every dialog that describes the Amazon
    /// arrival decision's current status — engine ruling plus
    /// outstanding check count, with an explicit caveat when the
    /// record hasn't been populated.
    private static func amazonArrivalReviewSentence(
        brief: ScenarioBriefContext
    ) -> String {
        guard brief.hasInteractedWithInputs else {
            return "Your Amazon arrival-order record doesn't have your inputs yet. "
                + "Open NomadFi's Decisions tab to enter your cart, Chase, and Wise details so the engine can recommend a payment path."
        }

        let outstanding = brief.decision.outstandingChecks.count
        let ruling = brief.decision.ruling

        let checksClause: String
        switch outstanding {
        case 0:
            checksClause = "No outstanding checks remain."
        default:
            checksClause = "\(formattedCheckCount(outstanding)) still need your input."
        }

        let tail: String
        switch brief.decision.primaryPath {
        case .awaitingUserInput, .reviewCartFirst:
            tail = "Open NomadFi's Decisions tab to finish the brief before NomadFi picks a card."
        case .chaseFreedomRiseUSD, .wiseUSD:
            tail = "Open NomadFi's Decisions tab for the full rationale and sources."
        }

        return "\(ruling) \(checksClause) \(tail)"
    }

    /// "1 check" / "N checks" — pluralized without a `Text` /
    /// `AttributedString` rendering layer since the output goes
    /// straight into an `IntentDialog`.
    private static func formattedCheckCount(_ count: Int) -> String {
        count == 1 ? "1 check" : "\(count) checks"
    }
}
