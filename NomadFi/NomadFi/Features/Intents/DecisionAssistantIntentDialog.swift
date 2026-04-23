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

    // MARK: - "Capture a decision" (Siri / Shortcuts intake)

    /// Dialog returned when the voice intake can't save because the
    /// user dictated nothing substantive. Never claims NomadFi
    /// analyzed or rejected a scenario — it just explains that a
    /// short description is required.
    static let draftCaptureMissingScenario: String =
        "I need a short description of the decision before I can save it. Try saying what you're weighing and run the shortcut again."

    /// Dialog returned after a successful draft capture. Intentionally
    /// explicit about three honesty constraints:
    ///
    ///   1. The draft is saved — not analyzed.
    ///   2. It is marked ``DecisionDraftStatus/needsEngine``.
    ///   3. NomadFi will not generate a recommendation from it until a
    ///      deterministic, source-backed engine covers the draft's
    ///      kind.
    ///
    /// These three rules are why the copy never uses "best", "lowest",
    /// "recommended", "analyzed", or "verified".
    static func draftCaptureSuccess(title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let titleClause = trimmedTitle.isEmpty
            ? ""
            : " Titled “\(trimmedTitle)”."
        return "Saved this as a decision draft in NomadFi.\(titleClause) "
            + "It is marked Needs engine, so NomadFi will not recommend anything from it "
            + "until a deterministic source-backed engine covers this kind of decision."
    }

    // MARK: - "Recommend a card" (generic purchase)

    /// Dialog returned when the user invokes ``RecommendCardIntent``
    /// without enough context — typically no amount. Ask, don't guess.
    static let recommendCardMissingAmount: String =
        "I need the amount you expect to pay before I can rank your saved accounts. Say the amount and run the shortcut again."

    /// Voice dialog for ``RecommendCardIntent``. Consumes the full
    /// ``PurchaseDecision`` and emits a concise, mission-safe spoken
    /// answer.
    ///
    /// Honesty constraints baked into this function:
    ///   - Never says "best card" on its own — the phrase "recommended
    ///     option" always appears in a sentence that clearly means
    ///     *NomadFi's current deterministic recommendation from your
    ///     saved inputs*.
    ///   - Never says "lowest fee" — the generic engine doesn't rank
    ///     on FX fee alone, so the spoken surface must not either.
    ///   - Never says "guaranteed", "score will increase", or "carry a
    ///     balance".
    ///   - Never invents rewards claims. A rewards-sensitive category
    ///     surfaces a single verification caveat when a credit card is
    ///     the recommendation.
    static func recommendCardAnswer(
        decision: PurchaseDecision
    ) -> String {
        switch decision.ruling {
        case .needsPurchaseContext:
            return recommendCardMissingAmount

        case .noPaymentAccountsOnFile:
            return "You don't have any non-investment accounts saved in NomadFi yet. Add a checking, credit-card, or wallet account in Settings to get a recommendation."

        case .missingCardData:
            let checks = formattedCheckCount(decision.outstandingCheckCount)
            return "NomadFi needs more account data before it can pick an option for this purchase. \(checks) remain — open the Decisions tab for details."

        case .allAccountsBlocked:
            return "None of your saved accounts clear the guardrails for this purchase. Open NomadFi's Decisions tab to see the caveats."

        case .ready:
            return recommendCardReadySentence(decision: decision)
        }
    }

    /// Dialog for ``ReviewCreditTimingIntent``. Consumes the Credit
    /// Timing engine's output and emits a concise voice summary.
    ///
    /// Never promises a credit-score outcome or a credit-limit
    /// increase. Never recommends carrying a balance. Highlights at
    /// most one card's most-urgent signal per sentence so the voice
    /// surface stays short.
    static func creditTimingReview(
        decision: CreditTimingDecision
    ) -> String {
        switch decision.ruling {
        case .noCreditCardsOnFile:
            return "You don't have any credit cards saved in NomadFi yet. Add one in Settings to run the Credit Timing engine."

        case .someNearLimit:
            let name = firstCardName(
                in: decision,
                matching: .nearLimitAvoidMoreSpend
            )
            return "Your \(name) is near its credit limit. Avoid additional spend on that card until the balance comes down. NomadFi does not predict credit-score outcomes."

        case .somePayDownBeforeClose:
            let name = firstCardName(
                in: decision,
                matching: .payDownBeforeClose
            )
            let checksTail = creditTimingChecksTail(decision: decision)
            return "Your \(name) would report a balance above a conservative planning target. Consider paying it down before statement close. Always pay the statement balance in full by the due date.\(checksTail)"

        case .missingData:
            let checks = formattedCheckCount(decision.outstandingCheckCount)
            return "NomadFi needs more data before it can give a full credit-timing ruling. \(checks) remain — open the Decisions tab to review what's missing."

        case .allCardsReady:
            return "All your saved credit cards look ready. Continue paying the statement balance in full by the due date. NomadFi does not predict credit-score outcomes."
        }
    }

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

    /// Builds the `.ready` sentence for ``recommendCardAnswer`` —
    /// extracted so the switch above stays readable.
    private static func recommendCardReadySentence(
        decision: PurchaseDecision
    ) -> String {
        guard let rec = decision.recommendation else {
            // Defence in depth: `.ready` implies a recommendation, but
            // if the engine ever ships without one we must not invent
            // an account name on the user's behalf.
            return "NomadFi couldn't finalise a recommended option for this purchase. Open the Decisions tab to review your saved accounts."
        }

        var parts: [String] = []
        parts.append(
            "NomadFi's recommended option for this purchase is your \(rec.accountName) — \(rec.accountTypeDisplay)."
        )

        if let fallback = decision.fallback {
            parts.append(
                "If that isn't available, fall back to your \(fallback.accountName)."
            )
        }

        if !rec.matchesPurchaseCurrency {
            if rec.foreignTransactionFeeIsVerified {
                parts.append(
                    "Heads up: this is a cross-currency purchase — verify the final converted amount against your issuer before committing."
                )
            } else {
                parts.append(
                    "Heads up: the foreign-transaction fee on this account hasn't been verified. Check your issuer's current terms before relying on it."
                )
            }
        }

        if decision.outstandingCheckCount > 0 {
            let checks = formattedCheckCount(decision.outstandingCheckCount)
            parts.append("\(checks) still need your input — open the Decisions tab for the list.")
        }

        if rec.isCreditCard {
            parts.append(
                "Pay the statement balance in full by the due date — NomadFi never recommends carrying a balance."
            )
        }

        appendRewardCopy(for: decision, into: &parts)

        return parts.joined(separator: " ")
    }

    /// Appends reward-specific copy to the `.ready` dialog. Covers
    /// three honesty cases:
    ///   1. Recommendation carries a verified + fresh rate → mention it.
    ///   2. Recommendation carries a rate but the source is
    ///      unverified or stale → say the rate was not used for
    ///      ranking and point at the editor.
    ///   3. Rewards-sensitive category and no candidate has a
    ///      verified rate on file → umbrella reminder to record one.
    private static func appendRewardCopy(
        for decision: PurchaseDecision,
        into parts: inout [String]
    ) {
        let rec = decision.recommendation
        let rewardEvaluation = rec?.rewardEvaluation ?? .empty

        if rewardEvaluation.isUsableForRanking,
           let rate = rewardEvaluation.displayRate {
            parts.append(
                "Verified rewards on file: \(rate). NomadFi included this in the ranking only because the source is verified and still fresh."
            )
            return
        }

        if rewardEvaluation.rate != nil {
            parts.append(
                "NomadFi has a rewards rate on file for this card but the source isn't verified or is past its freshness window — the rate was not used to rank. Confirm it in Settings → Account → Rewards Terms to include rewards next time."
            )
            return
        }

        if decision.context.category.isRewardsSensitive {
            let anyVerified = decision.candidates.contains {
                $0.rewardEvaluation.isVerifiedAndFresh
            }
            if !anyVerified {
                parts.append(
                    "NomadFi does not have verified rewards on file for your cards — record them in Settings → Account → Rewards Terms so the engine can include rewards in the ranking."
                )
            }
        }
    }

    /// Name of the first assessment whose ruling matches `ruling`, or
    /// a calm fallback phrase when the catalog has grown past what
    /// this copy covers.
    private static func firstCardName(
        in decision: CreditTimingDecision,
        matching ruling: CreditTimingCardRuling
    ) -> String {
        decision.cardAssessments
            .first(where: { $0.ruling == ruling })?
            .accountName ?? "one of your cards"
    }

    /// Optional trailing sentence that lists remaining outstanding
    /// checks for the credit-timing review dialog. Empty string when
    /// nothing is outstanding so the sentence flows naturally.
    private static func creditTimingChecksTail(
        decision: CreditTimingDecision
    ) -> String {
        guard decision.outstandingCheckCount > 0 else { return "" }
        let checks = formattedCheckCount(decision.outstandingCheckCount)
        return " \(checks) still need your input — open the Decisions tab for details."
    }
}
