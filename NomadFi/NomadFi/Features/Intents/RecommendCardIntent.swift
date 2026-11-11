// RecommendCardIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Which card should I use at <merchant> for
// <amount> <currency> in <location> in NomadFi."
//
// Runs the deterministic ``PurchaseDecisionEngine`` against the
// user's saved accounts and speaks a concise, mission-safe answer.
// The voice layer adds *no* logic of its own — it only plumbs the
// user's spoken inputs into the engine and reads the engine's
// structured output aloud.
//
// Intentionally conservative:
//   - `supportedModes = .background` — never opens the app.
//   - The spoken answer is transient. NomadFi never persists the
//     voice query. Users who want to capture the scenario as a
//     durable draft should use `CaptureDecisionDraftIntent`.
//   - No rewards ranking, no "best card" / "lowest fee" framing, no
//     credit-score claims, no Apple Pay / Wallet / FinanceKit
//     dependency.

import AppIntents

/// Generic purchase-ranking voice intent. The engine does the
/// ranking; this file only marshals parameters and speaks the result.
struct RecommendCardIntent: AppIntent {

    static let title: LocalizedStringResource = "Recommend a Card"

    static let description: IntentDescription = IntentDescription(
        "Ask NomadFi which saved payment method clears the hard rules for a purchase. The engine is deterministic — it will not invent rewards claims or predict a credit-score outcome."
    )

    /// Voice-only recommendation; no app activation.
    static let supportedModes: IntentModes = .background

    /// Financial data never answers, or changes, from a locked iPhone:
    /// Siri and Shortcuts ask for Face ID, Touch ID or the passcode first.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    // MARK: - Parameters

    @Parameter(
        title: "Amount",
        description: "How much you expect to pay, in the purchase currency."
    )
    var amount: Double

    @Parameter(
        title: "Currency",
        description: "Currency the merchant will bill you in."
    )
    var currency: CurrencyCodeAppEnum?

    @Parameter(
        title: "Category",
        description: "Optional purchase category."
    )
    var category: MerchantCategoryAppEnum?

    @Parameter(
        title: "Merchant",
        description: "Optional merchant or counterparty name."
    )
    var merchantName: String?

    @Parameter(
        title: "Location",
        description: "Optional city or short location hint. Do not enter a full address."
    )
    var locationHint: String?

    @Parameter(
        title: "Timing",
        description: "Optional — urgency note in your own words (\"before the trip\")."
    )
    var timingText: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedCurrency = currency?.currencyCode ?? .usd
        let resolvedCategory = category?.merchantCategory ?? .general
        let trimmedMerchant = (merchantName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = (locationHint ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTiming = (timingText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Guard against non-positive amounts — Siri can still end up
        // passing a negative or zero literal. The engine's
        // `.needsPurchaseContext` ruling handles this gracefully, but
        // we surface the ask-for-amount dialog directly so the user
        // hears an immediate correction.
        guard amount > 0 else {
            let dialog = DecisionAssistantIntentDialog.recommendCardMissingAmount
            return .result(dialog: "\(dialog)")
        }

        let context = PurchaseContext(
            merchantName: trimmedMerchant,
            category: resolvedCategory,
            amount: amount,
            currencyCode: resolvedCurrency,
            countryCode: trimmedLocation,
            timingText: trimmedTiming
        )

        let decision = try DecisionAssistantIntentContext
            .runPurchaseDecision(context: context)

        let dialog = DecisionAssistantIntentDialog
            .recommendCardAnswer(decision: decision)
        return .result(dialog: "\(dialog)")
    }
}
