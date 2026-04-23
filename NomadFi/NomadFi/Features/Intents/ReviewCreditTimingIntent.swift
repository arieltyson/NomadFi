// ReviewCreditTimingIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Review my credit timing in NomadFi."
//
// Runs the deterministic ``CreditTimingDecisionEngine`` against the
// user's saved credit-card accounts and speaks a concise, mission-
// safe review — near-limit warnings, paydown-before-close prompts,
// stale-snapshot caveats, or an "all cards ready" summary.
//
// Intentionally conservative:
//   - `supportedModes = .background` — never opens the app.
//   - Spoken output is transient; nothing is persisted.
//   - Never promises a credit-score outcome, a credit-limit increase,
//     or any "carry a balance for rewards" framing. The engine and
//     dialog formatter both refuse that language.

import AppIntents

/// Voice review of the user's portfolio-level credit-timing state.
struct ReviewCreditTimingIntent: AppIntent {

    static let title: LocalizedStringResource = "Review Credit Timing"

    static let description: IntentDescription = IntentDescription(
        "Hear NomadFi's deterministic credit-timing check across your saved credit cards — near-limit warnings, paydown-before-close prompts, or a calm \"all cards ready\" read."
    )

    /// Voice-only review; no app activation.
    static let supportedModes: IntentModes = .background

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let decision = try DecisionAssistantIntentContext
            .runCreditTimingDecision()

        let dialog = DecisionAssistantIntentDialog
            .creditTimingReview(decision: decision)
        return .result(dialog: "\(dialog)")
    }
}
