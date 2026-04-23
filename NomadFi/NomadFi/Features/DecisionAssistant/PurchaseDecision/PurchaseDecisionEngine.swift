// PurchaseDecisionEngine.swift
// NomadFi
//
// Pure, testable engine behind the generic purchase decision brief.
// Consumes a `PurchaseContext` (merchant, category, amount,
// currency, country, timing) + the user's `[Account]` rows and
// produces a `PurchaseDecision` — one recommended payment method, a
// fallback, and caveated / blocked candidates.
//
// Hard invariants pinned in code and in tests:
//   - Nil balances are never treated as zero.
//   - Investment accounts are never payment methods.
//   - A stale snapshot never produces a strong recommendation.
//   - Rewards are never used for ranking in v1 — NomadFi has no
//     verified rewards data yet, and the copy says so.
//   - The engine never claims a credit-score or limit-increase
//     outcome and never recommends carrying a balance.
//   - All user-facing dates are absolute (no "soon", no "today").

import Foundation

/// The deterministic generic purchase engine.
enum PurchaseDecisionEngine {

    // MARK: - Thresholds

    /// Conservative projected-utilization cap the engine uses to
    /// decide whether a credit card should be promoted to
    /// ``PurchaseCandidateStance/recommended`` vs. demoted to
    /// ``PurchaseCandidateStance/usableWithCaveats``.
    static let conservativeProjectedUtilization: Double = 0.30

    // MARK: - Hard rules

    static let hardRules: [String] = [
        "Always pay the statement balance in full by the due date. NomadFi never recommends carrying a balance or taking a cash advance for rewards.",
        "Credit scoring is multi-factor. NomadFi cannot promise a specific credit-score outcome from any single purchase decision.",
        "Rewards require verified card terms. NomadFi does not model category multipliers yet — verify any claimed bonus on the issuer's current product page before treating it as a factor.",
        "NomadFi never guarantees card acceptance, credit-limit increases, or that any method will be the cheapest in every future cycle.",
    ]

    // MARK: - Public API

    /// Produces the full purchase decision for the supplied context
    /// and account list.
    static func decide(
        context: PurchaseContext,
        accounts: [Account],
        now: Date = .now
    ) -> PurchaseDecision {
        // Always run per-account filtering so the UI can surface
        // excluded investment rows even when the amount is missing.
        let raw = accounts.map {
            assess($0, context: context, now: now)
        }

        let sorted = raw.sorted(by: severityDescending)

        // When the purchase is not usable yet, the engine refuses to
        // pick a winner even if candidates exist. Every usable
        // candidate is demoted to `.usableWithCaveats` so the UI can
        // still show the user what their options look like once they
        // fill in the amount.
        let decorated = decorate(
            candidates: sorted,
            contextIsUsable: context.hasUsableAmount
        )

        let ruling = topLevelRuling(
            candidates: decorated,
            context: context
        )

        let recommendation = decorated.first { $0.stance == .recommended }
        let fallback = decorated.first { $0.stance == .fallback }

        return PurchaseDecision(
            context: context,
            ruling: ruling,
            recommendation: recommendation,
            fallback: fallback,
            candidates: decorated,
            whenNotToUseWarnings: warnings(
                for: recommendation,
                fallback: fallback,
                context: context
            ),
            missingDataChecklist: aggregatedChecks(
                candidates: decorated,
                context: context
            ),
            hardRules: hardRules,
            citations: PurchaseDecisionCitationCatalog.purchaseDecision,
            evaluatedAt: now
        )
    }
}

// MARK: - Per-account assessment

private extension PurchaseDecisionEngine {

    static func assess(
        _ account: Account,
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        if account.accountType == .investment {
            return baseAssessment(
                account,
                stance: .excludedInvestment,
                reasons: [
                    "Investment accounts are not a payment method in NomadFi.",
                ],
                outstandingChecks: [],
                context: context,
                now: now
            )
        }

        if account.isCreditCard {
            return assessCreditCard(account, context: context, now: now)
        }

        return assessDeposit(account, context: context, now: now)
    }

    static func assessCreditCard(
        _ account: Account,
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let displayName = accountDisplayName(for: account)

        // Setup gate: without a limit or a current balance the engine
        // refuses to reason about this card.
        if account.creditLimit == nil || account.currentBalance == nil {
            let missing = missingCreditCardSetupChecks(for: account, displayName: displayName)
            return baseAssessment(
                account,
                stance: .needsSetup,
                reasons: ["Missing credit limit or current balance on this card."],
                outstandingChecks: missing,
                context: context,
                now: now
            )
        }

        let snapshotIsStale = account.hasFinancialSnapshot
            && account.isFinancialSnapshotStale(now: now)

        if snapshotIsStale {
            return baseAssessment(
                account,
                stance: .snapshotStale,
                reasons: ["Latest balance snapshot is past its freshness window — no strong recommendation."],
                outstandingChecks: [
                    "Refresh the balance snapshot for \(displayName) in Settings → Financial Setup → Accounts.",
                ],
                context: context,
                now: now
            )
        }

        // Coverage check — only meaningful when currencies match; a
        // cross-currency amount compared against a same-currency
        // available credit would be a unit error. Flag the FX case
        // as a caveat instead of a blocker.
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        let projectedAvailableCredit = projectedAvailableCredit(for: account)

        if sameCurrency,
           let purchaseAmount = context.amount,
           purchaseAmount > 0,
           let projected = projectedAvailableCredit,
           projected < purchaseAmount {
            return baseAssessment(
                account,
                stance: .insufficientCreditCoverage,
                reasons: [
                    "Available credit on this card is below the purchase amount.",
                ],
                outstandingChecks: [],
                context: context,
                now: now
            )
        }

        var reasons: [String] = []
        var checks: [String] = []

        // Projected utilization messaging — only when we have enough
        // signal to compute it honestly.
        if sameCurrency, let purchaseAmount = context.amount,
           let limit = account.creditLimit, limit > 0,
           let balance = account.currentBalance {
            let projectedUtil = (balance + purchaseAmount) / limit
            if projectedUtil > conservativeProjectedUtilization {
                let percent = (projectedUtil * 100)
                    .formatted(.number.precision(.fractionLength(1)))
                reasons.append(
                    "Projected utilization after this purchase is ≈ \(percent)% — above NomadFi's conservative planning target."
                )
            }
        }

        // Schedule signal.
        let schedule = CreditCardSchedule(account: account)
        switch schedule.state {
        case .confirmed:
            if let closing = schedule.statementClosingDate {
                let formatted = closing.formatted(
                    .dateTime.year().month(.wide).day()
                )
                reasons.append(
                    "Confirmed statement calendar — statement closes \(formatted). Pay the statement balance by the due date."
                )
            }
        case .partial:
            checks.append(
                "Complete the statement calendar for \(displayName) in Settings → Credit Card Calendar."
            )
            reasons.append("Statement calendar is not fully confirmed.")
        case .missing:
            checks.append(
                "Add the statement calendar for \(displayName) in Settings → Credit Card Calendar."
            )
            reasons.append("No statement calendar on file.")
        case .needsAttention:
            checks.append(
                "Review the statement calendar for \(displayName) — the dates aren't in a valid order."
            )
            reasons.append("Statement calendar dates need attention.")
        }

        // FX signal.
        let fxInfo = foreignTransactionInfo(
            account: account,
            context: context,
            now: now
        )
        if let note = fxInfo.reason {
            reasons.append(note)
        }
        checks.append(contentsOf: fxInfo.checks)

        // Decide on stance: if schedule confirmed + coverage OK + no
        // hard caveat, we consider this a candidate. The picker in
        // `decorate(candidates:)` will promote exactly one as
        // `.recommended` and one as `.fallback`.
        let stance: PurchaseCandidateStance = .usableWithCaveats

        return finalAssessment(
            account,
            stance: stance,
            reasons: reasons,
            outstandingChecks: checks,
            context: context,
            fxInfo: fxInfo,
            now: now
        )
    }

    static func assessDeposit(
        _ account: Account,
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let displayName = accountDisplayName(for: account)
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        let availableFunds = account.latestBalanceForDisplay

        if availableFunds == nil {
            return baseAssessment(
                account,
                stance: .needsSetup,
                reasons: ["No current balance on file for this account."],
                outstandingChecks: [
                    "Enter a current balance snapshot for \(displayName) in Settings → Financial Setup → Accounts.",
                ],
                context: context,
                now: now
            )
        }

        if sameCurrency,
           let purchaseAmount = context.amount,
           purchaseAmount > 0,
           let funds = availableFunds,
           funds < purchaseAmount {
            return baseAssessment(
                account,
                stance: .insufficientFunds,
                reasons: ["Known balance is below the purchase amount."],
                outstandingChecks: [],
                context: context,
                now: now
            )
        }

        var reasons: [String] = []
        var checks: [String] = []

        let fxInfo = foreignTransactionInfo(
            account: account,
            context: context,
            now: now
        )
        if let note = fxInfo.reason {
            reasons.append(note)
        }
        checks.append(contentsOf: fxInfo.checks)

        return finalAssessment(
            account,
            stance: .usableWithCaveats,
            reasons: reasons,
            outstandingChecks: checks,
            context: context,
            fxInfo: fxInfo,
            now: now
        )
    }

    // MARK: - Helpers

    static func missingCreditCardSetupChecks(
        for account: Account,
        displayName: String
    ) -> [String] {
        var checks: [String] = []
        if account.creditLimit == nil {
            checks.append(
                "Enter the credit limit for \(displayName) in Settings → Financial Setup → Accounts."
            )
        }
        if account.currentBalance == nil {
            checks.append(
                "Enter a current balance snapshot for \(displayName)."
            )
        }
        return checks
    }

    static func projectedAvailableCredit(for account: Account) -> Double? {
        if let explicit = account.availableCredit {
            return explicit
        }
        guard let limit = account.creditLimit,
              let balance = account.currentBalance
        else {
            return nil
        }
        let computed = limit - balance
        return computed > 0 ? computed : 0
    }

    struct ForeignTransactionInfo: Sendable, Equatable {
        let feePercent: Double?
        let isVerified: Bool
        let reason: String?
        let checks: [String]
    }

    static func foreignTransactionInfo(
        account: Account,
        context: PurchaseContext,
        now: Date
    ) -> ForeignTransactionInfo {
        let matches = account.currencyCodeRawValue == context.currencyCode.rawValue
        guard !matches else {
            return ForeignTransactionInfo(
                feePercent: nil,
                isVerified: true,
                reason: nil,
                checks: []
            )
        }

        let provenance = account.foreignTransactionFeeProvenance
        let effective = SourceFreshness.effectiveConfidence(
            for: provenance,
            domain: .issuerCardTerms,
            now: now
        )
        let isVerified = effective.isVerified

        let displayName = accountDisplayName(for: account)
        let feePercent = account.foreignTransactionFeePercent
        let formattedFee = feePercent.formatted(
            .number.precision(.fractionLength(1))
        )

        let reason: String
        if isVerified {
            reason = "Foreign-transaction fee on this account is \(formattedFee)% — converted via issuer terms. Verify the final amount against your issuer's current page."
        } else {
            reason = "NomadFi has an unverified foreign-transaction fee on this account. FX conversion needs verification before treating this as a firm cost."
        }

        var checks: [String] = []
        checks.append(
            "Verify the foreign-currency conversion and any card acceptance for \(displayName) on the issuer's current product page or cardmember agreement."
        )
        return ForeignTransactionInfo(
            feePercent: feePercent,
            isVerified: isVerified,
            reason: reason,
            checks: checks
        )
    }

    static func baseAssessment(
        _ account: Account,
        stance: PurchaseCandidateStance,
        reasons: [String],
        outstandingChecks: [String],
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        return PurchaseCandidateAssessment(
            id: identifier(for: account),
            accountName: accountDisplayName(for: account),
            institutionName: account.institutionName,
            accountTypeDisplay: account.accountType?.displayName ?? "Account",
            currencyCode: account.currencyCodeRawValue,
            matchesPurchaseCurrency: sameCurrency,
            stance: stance,
            reasons: reasons,
            outstandingChecks: outstandingChecks,
            currentBalance: account.currentBalance ?? account.latestBalanceForDisplay,
            creditLimit: account.creditLimit,
            availableCredit: projectedAvailableCredit(for: account),
            isCreditCard: account.isCreditCard,
            foreignTransactionFeePercent: nil,
            foreignTransactionFeeIsVerified: sameCurrency
        )
    }

    static func finalAssessment(
        _ account: Account,
        stance: PurchaseCandidateStance,
        reasons: [String],
        outstandingChecks: [String],
        context: PurchaseContext,
        fxInfo: ForeignTransactionInfo,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        return PurchaseCandidateAssessment(
            id: identifier(for: account),
            accountName: accountDisplayName(for: account),
            institutionName: account.institutionName,
            accountTypeDisplay: account.accountType?.displayName ?? "Account",
            currencyCode: account.currencyCodeRawValue,
            matchesPurchaseCurrency: sameCurrency,
            stance: stance,
            reasons: reasons,
            outstandingChecks: outstandingChecks,
            currentBalance: account.currentBalance ?? account.latestBalanceForDisplay,
            creditLimit: account.creditLimit,
            availableCredit: projectedAvailableCredit(for: account),
            isCreditCard: account.isCreditCard,
            foreignTransactionFeePercent: fxInfo.feePercent,
            foreignTransactionFeeIsVerified: fxInfo.isVerified
        )
    }

    // MARK: - Ranking

    /// Score tuple for ranking usable candidates. Lower is better.
    ///
    /// Ordering:
    ///   1. Same-currency accounts beat cross-currency ones.
    ///   2. Non-credit (deposit / wallet) beats credit card —
    ///      NomadFi avoids promoting debt-risk paths over
    ///      pay-now-from-funds paths when no verified rewards
    ///      data differentiates them.
    ///   3. Credit cards with a fully verified FX fee beat ones
    ///      with an unverified FX fee, when both are usable.
    ///   4. Stable tiebreaker: institution + account name.
    static func rankingScore(
        _ assessment: PurchaseCandidateAssessment
    ) -> (Int, Int, Int, String, String) {
        let currencyScore = assessment.matchesPurchaseCurrency ? 0 : 1
        let debtRiskScore = assessment.isCreditCard ? 1 : 0
        let fxVerifiedScore = assessment.foreignTransactionFeeIsVerified ? 0 : 1
        return (
            currencyScore,
            debtRiskScore,
            fxVerifiedScore,
            assessment.institutionName,
            assessment.accountName
        )
    }

    /// Severity ordering for the brief sheet. Usable candidates
    /// render first; blocked / excluded rows fall to the bottom.
    static func severityRank(
        _ stance: PurchaseCandidateStance
    ) -> Int {
        switch stance {
        case .usableWithCaveats, .recommended, .fallback: 0
        case .insufficientFunds: 1
        case .insufficientCreditCoverage: 2
        case .snapshotStale: 3
        case .needsSetup: 4
        case .excludedInvestment: 5
        }
    }

    static func severityDescending(
        _ lhs: PurchaseCandidateAssessment,
        _ rhs: PurchaseCandidateAssessment
    ) -> Bool {
        let lhsRank = severityRank(lhs.stance)
        let rhsRank = severityRank(rhs.stance)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return rankingScore(lhs) < rankingScore(rhs)
    }

    /// Promotes the best usable candidate to `.recommended` and the
    /// next one to `.fallback`. Everything else stays
    /// `.usableWithCaveats` (unless it's already a blocker).
    static func decorate(
        candidates: [PurchaseCandidateAssessment],
        contextIsUsable: Bool
    ) -> [PurchaseCandidateAssessment] {
        guard contextIsUsable else {
            // Without a usable amount the engine refuses to rank.
            return candidates
        }

        // Usable candidates in ranking order.
        let usables = candidates
            .filter { $0.stance == .usableWithCaveats }
            .sorted { rankingScore($0) < rankingScore($1) }

        guard !usables.isEmpty else {
            return candidates
        }

        var result = candidates
        if let winner = usables.first,
           let idx = result.firstIndex(where: { $0.id == winner.id }) {
            result[idx] = result[idx].with(stance: .recommended)
        }
        if usables.count > 1,
           let idx = result.firstIndex(where: { $0.id == usables[1].id }) {
            result[idx] = result[idx].with(stance: .fallback)
        }
        return result
    }

    // MARK: - Aggregation

    static func topLevelRuling(
        candidates: [PurchaseCandidateAssessment],
        context: PurchaseContext
    ) -> PurchaseDecisionRuling {
        if candidates.isEmpty {
            return .noPaymentAccountsOnFile
        }
        // Treat `excludedInvestment` as "no payment method" for the
        // purpose of the top-level ruling — users with only
        // investment accounts still see that message.
        let paymentMethods = candidates.filter { $0.stance != .excludedInvestment }
        if paymentMethods.isEmpty {
            return .noPaymentAccountsOnFile
        }

        if !context.hasUsableAmount {
            return .needsPurchaseContext
        }

        if candidates.contains(where: { $0.stance == .recommended }) {
            return .ready
        }

        let onlyUsable = paymentMethods.allSatisfy { $0.stance.isUsable }
        let hasMissingData = paymentMethods.contains { candidate in
            candidate.stance == .needsSetup
                || candidate.stance == .snapshotStale
        }

        if !onlyUsable && hasMissingData {
            return .missingCardData
        }
        return .allAccountsBlocked
    }

    static func aggregatedChecks(
        candidates: [PurchaseCandidateAssessment],
        context: PurchaseContext
    ) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for candidate in candidates {
            for check in candidate.outstandingChecks where seen.insert(check).inserted {
                ordered.append(check)
            }
        }
        // Add the single "rewards not modelled" check for
        // rewards-sensitive categories — consolidated across the
        // portfolio so the UI isn't noisy.
        if context.category.isRewardsSensitive {
            let rewardsNote = "Verify any category rewards bonus (\(context.category.displayLabel)) on the issuer's current product page — NomadFi does not model verified rewards yet."
            if seen.insert(rewardsNote).inserted {
                ordered.append(rewardsNote)
            }
        }
        return ordered
    }

    static func warnings(
        for recommendation: PurchaseCandidateAssessment?,
        fallback: PurchaseCandidateAssessment?,
        context: PurchaseContext
    ) -> [String] {
        var warnings: [String] = []
        if let recommendation {
            if recommendation.isCreditCard {
                warnings.append(
                    "Don't rely on this recommendation to carry a balance past the due date — NomadFi never promotes interest-bearing balances."
                )
            }
            if !recommendation.matchesPurchaseCurrency {
                warnings.append(
                    "Purchase currency and account currency differ. Verify the final converted amount before you commit."
                )
            }
        }
        if let fallback, fallback.isCreditCard, recommendation?.isCreditCard == false {
            warnings.append(
                "The fallback is a credit card. Treat it as a pay-in-full path, not a financing path."
            )
        }
        return warnings
    }

    // MARK: - Identity

    static func identifier(for account: Account) -> String {
        let institution = account.institutionName.isEmpty
            ? "unknown-issuer"
            : account.institutionName
        let name = account.name.isEmpty ? "unnamed-account" : account.name
        return "purchase-\(institution)-\(name)"
    }

    static func accountDisplayName(for account: Account) -> String {
        let name = account.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        let institution = account.institutionName.trimmingCharacters(in: .whitespaces)
        if !institution.isEmpty { return institution }
        return "this account"
    }
}

// MARK: - Assessment mutation helper

private extension PurchaseCandidateAssessment {

    /// Returns a copy with a different stance. Used by the engine's
    /// ranking pass to promote the top two usables to
    /// `.recommended` / `.fallback` without recomputing the rest.
    func with(stance newStance: PurchaseCandidateStance) -> PurchaseCandidateAssessment {
        PurchaseCandidateAssessment(
            id: id,
            accountName: accountName,
            institutionName: institutionName,
            accountTypeDisplay: accountTypeDisplay,
            currencyCode: currencyCode,
            matchesPurchaseCurrency: matchesPurchaseCurrency,
            stance: newStance,
            reasons: reasons,
            outstandingChecks: outstandingChecks,
            currentBalance: currentBalance,
            creditLimit: creditLimit,
            availableCredit: availableCredit,
            isCreditCard: isCreditCard,
            foreignTransactionFeePercent: foreignTransactionFeePercent,
            foreignTransactionFeeIsVerified: foreignTransactionFeeIsVerified
        )
    }
}
