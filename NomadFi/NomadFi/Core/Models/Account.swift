import Foundation
import SwiftData

@Model
final class Account {
    var name: String = ""
    var institutionName: String = ""
    var accountTypeRawValue: String = AccountType.checking.rawValue
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue
    var balance: Double = 0
    var jurisdiction: String = ""
    var isFinanceKitLinked: Bool = false
    var foreignTransactionFeePercent: Double = 0

    // Provenance fields for `foreignTransactionFeePercent`. Stored as
    // CloudKit-safe primitives: all optional with sensible defaults. See
    // `SourceProvenance` and `docs/README.md` for the evidence hierarchy
    // these values map into.
    var foreignTransactionFeeSourceName: String? = nil
    var foreignTransactionFeeSourceURL: String? = nil
    var foreignTransactionFeeSourceConfidenceRaw: String? = nil
    var foreignTransactionFeeSourceVerifiedAt: Date? = nil
    var foreignTransactionFeeSourceNotes: String? = nil

    var createdAt: Date = Date.now
    var lastUpdatedAt: Date = Date.now

    // Credit-card statement calendar metadata. Only meaningful when
    // `accountType == .creditCard`. Stored as CloudKit-safe optionals —
    // absent values mean "not yet entered", never zero. The
    // authoritative source is the issuer's app; NomadFi only stores
    // what the user confirms.
    var statementPeriodStartDate: Date? = nil
    var statementClosingDate: Date? = nil
    var paymentDueDate: Date? = nil
    var statementScheduleLastConfirmedAt: Date? = nil

    // Durable provider link fields. Phase 5B: replace the narrow
    // `isFinanceKitLinked` bool as the main identity signal with a
    // provider-neutral stamp. All optional + defaulted so existing
    // rows migrate forward without touching the CloudKit schema
    // contract. A row is considered "linked" when both
    // `providerLinkKindRawValue` and `providerExternalAccountID` are
    // set — the reconciler uses that pair as the durable match key.
    //
    // The raw value stores a ``FinancialDataProviderKind``'s
    // `logKey` (e.g. `"finance_kit"`, `"external_aggregator.acme"`)
    // rather than the associated-value enum directly, so the schema
    // stays schema-stable across candidate aggregator identifiers.
    var providerLinkKindRawValue: String? = nil
    var providerExternalAccountID: String? = nil
    var providerConnectionID: String? = nil
    var providerInstitutionIdentifier: String? = nil
    var providerLastSyncedAt: Date? = nil

    // Live financial snapshot fields. Every value is optional because a
    // snapshot is a point-in-time read of the issuer's app — absent
    // means "the user has not told NomadFi yet", never zero. Stored as
    // CloudKit-safe primitives: all optional with sensible defaults.
    //
    // Credit cards populate `creditLimit`, `currentBalance`,
    // `availableCredit`, and `statementBalance`. Deposit/wallet/
    // investment accounts typically populate only `currentBalance`.
    // Legacy ``balance`` is retained for migration from Phase 0 rows
    // that pre-date snapshots.
    var creditLimit: Double? = nil
    var currentBalance: Double? = nil
    var availableCredit: Double? = nil
    var statementBalance: Double? = nil
    var financialSnapshotUpdatedAt: Date? = nil
    var financialSnapshotSourceRawValue: String? = nil

    // Verified rewards terms. Only meaningful when
    // `accountType == .creditCard`. Every field is optional and has
    // a safe default so CloudKit-synced stores stay schema-stable
    // across installs that haven't filled any of this in.
    //
    // The category overrides are stored as a single JSON String
    // (`rewardCategoryOverridesRaw`) so a new `MerchantCategory`
    // case is additive rather than a schema migration. The
    // accompanying provenance fields mirror the shape used for
    // `foreignTransactionFee*`, letting `SourceFreshness` gate
    // reward trust identically to FX trust.
    var rewardProgramName: String? = nil
    var rewardUnitRawValue: String? = nil
    var baseRewardRate: Double? = nil
    var rewardCategoryOverridesRaw: String? = nil
    var rewardSourceName: String? = nil
    var rewardSourceURL: String? = nil
    var rewardSourceConfidenceRaw: String? = nil
    var rewardSourceVerifiedAt: Date? = nil
    var rewardSourceNotes: String? = nil

    var jurisdictionProfile: JurisdictionProfile?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .cascade, inverse: \Subscription.account)
    var subscriptions: [Subscription]?

    var currencyCode: CurrencyCode? {
        CurrencyCode(rawValue: currencyCodeRawValue)
    }

    var accountType: AccountType? {
        AccountType(rawValue: accountTypeRawValue)
    }

    /// Provenance for the `foreignTransactionFeePercent` value.
    ///
    /// Reconstructs a ``SourceProvenance`` from the persisted primitive
    /// fields. Defaults to ``SourceProvenance/userEnteredAccountFee(accessedAt:)``
    /// when no confidence has been recorded — user-entered fees are never
    /// treated as verified without an explicit upgrade.
    var foreignTransactionFeeProvenance: SourceProvenance {
        let confidence = foreignTransactionFeeSourceConfidenceRaw
            .flatMap(SourceConfidence.init(rawValue:))
            ?? .userProvided

        let scope = JurisdictionScope(countryCode: jurisdiction)

        if let name = foreignTransactionFeeSourceName, !name.isEmpty {
            return SourceProvenance(
                name: name,
                urlString: foreignTransactionFeeSourceURL,
                type: confidence.isVerified ? .issuerDisclosure : .userEntered,
                confidence: confidence,
                jurisdiction: scope,
                accessedAt: foreignTransactionFeeSourceVerifiedAt,
                publishedAt: nil,
                notes: foreignTransactionFeeSourceNotes
            )
        }

        var provenance = SourceProvenance.userEnteredAccountFee(
            accessedAt: foreignTransactionFeeSourceVerifiedAt
        )
        provenance.jurisdiction = scope
        return provenance
    }

    init(
        name: String = "",
        institutionName: String = "",
        accountType: AccountType = .checking,
        currencyCode: CurrencyCode = .usd,
        balance: Double = 0,
        jurisdiction: String = "",
        isFinanceKitLinked: Bool = false,
        foreignTransactionFeePercent: Double = 0,
        foreignTransactionFeeSourceName: String? = nil,
        foreignTransactionFeeSourceURL: String? = nil,
        foreignTransactionFeeSourceConfidence: SourceConfidence? = nil,
        foreignTransactionFeeSourceVerifiedAt: Date? = nil,
        foreignTransactionFeeSourceNotes: String? = nil,
        createdAt: Date = .now,
        lastUpdatedAt: Date = .now,
        statementPeriodStartDate: Date? = nil,
        statementClosingDate: Date? = nil,
        paymentDueDate: Date? = nil,
        statementScheduleLastConfirmedAt: Date? = nil,
        creditLimit: Double? = nil,
        currentBalance: Double? = nil,
        availableCredit: Double? = nil,
        statementBalance: Double? = nil,
        financialSnapshotUpdatedAt: Date? = nil,
        financialSnapshotSource: FinancialSnapshotSource? = nil,
        providerLinkKindRawValue: String? = nil,
        providerExternalAccountID: String? = nil,
        providerConnectionID: String? = nil,
        providerInstitutionIdentifier: String? = nil,
        providerLastSyncedAt: Date? = nil,
        rewardProgramName: String? = nil,
        rewardUnit: RewardUnit? = nil,
        baseRewardRate: Double? = nil,
        rewardCategoryOverrides: [MerchantCategory: Double] = [:],
        rewardSourceName: String? = nil,
        rewardSourceURL: String? = nil,
        rewardSourceConfidence: SourceConfidence? = nil,
        rewardSourceVerifiedAt: Date? = nil,
        rewardSourceNotes: String? = nil,
        jurisdictionProfile: JurisdictionProfile? = nil,
        transactions: [Transaction]? = nil,
        subscriptions: [Subscription]? = nil
    ) {
        self.name = name
        self.institutionName = institutionName
        self.accountTypeRawValue = accountType.rawValue
        self.currencyCodeRawValue = currencyCode.rawValue
        self.balance = balance
        self.jurisdiction = jurisdiction
        self.isFinanceKitLinked = isFinanceKitLinked
        self.foreignTransactionFeePercent = foreignTransactionFeePercent
        self.foreignTransactionFeeSourceName = foreignTransactionFeeSourceName
        self.foreignTransactionFeeSourceURL = foreignTransactionFeeSourceURL
        self.foreignTransactionFeeSourceConfidenceRaw = foreignTransactionFeeSourceConfidence?.rawValue
        self.foreignTransactionFeeSourceVerifiedAt = foreignTransactionFeeSourceVerifiedAt
        self.foreignTransactionFeeSourceNotes = foreignTransactionFeeSourceNotes
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.statementPeriodStartDate = statementPeriodStartDate
        self.statementClosingDate = statementClosingDate
        self.paymentDueDate = paymentDueDate
        self.statementScheduleLastConfirmedAt = statementScheduleLastConfirmedAt
        self.creditLimit = creditLimit
        self.currentBalance = currentBalance
        self.availableCredit = availableCredit
        self.statementBalance = statementBalance
        self.financialSnapshotUpdatedAt = financialSnapshotUpdatedAt
        self.financialSnapshotSourceRawValue = financialSnapshotSource?.rawValue
        self.providerLinkKindRawValue = providerLinkKindRawValue
        self.providerExternalAccountID = providerExternalAccountID
        self.providerConnectionID = providerConnectionID
        self.providerInstitutionIdentifier = providerInstitutionIdentifier
        self.providerLastSyncedAt = providerLastSyncedAt
        self.rewardProgramName = rewardProgramName
        self.rewardUnitRawValue = rewardUnit?.rawValue
        self.baseRewardRate = baseRewardRate
        self.rewardCategoryOverridesRaw = RewardProfile
            .encodedCategoryOverrides(rewardCategoryOverrides)
        self.rewardSourceName = rewardSourceName
        self.rewardSourceURL = rewardSourceURL
        self.rewardSourceConfidenceRaw = rewardSourceConfidence?.rawValue
        self.rewardSourceVerifiedAt = rewardSourceVerifiedAt
        self.rewardSourceNotes = rewardSourceNotes
        self.jurisdictionProfile = jurisdictionProfile
        self.transactions = transactions
        self.subscriptions = subscriptions
    }
}

// MARK: - Snapshot helpers

extension Account {

    /// Convenience: true iff this account models a credit card.
    var isCreditCard: Bool {
        accountType?.isCreditCard ?? false
    }

    /// True when this account carries a durable upstream link — both
    /// a provider kind and an external ID are on file. Used by the
    /// reconciler to pick a conservative match rather than falling
    /// back to a heuristic match. `isFinanceKitLinked` is retained
    /// as a legacy field; this value is the authoritative signal.
    var hasProviderLink: Bool {
        let kind = providerLinkKindRawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let externalID = providerExternalAccountID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !kind.isEmpty && !externalID.isEmpty
    }

    /// Source of the latest financial snapshot, defaulting to
    /// ``FinancialSnapshotSource/unknown`` when the row pre-dates
    /// snapshot provenance.
    var latestSnapshotSource: FinancialSnapshotSource {
        guard let raw = financialSnapshotSourceRawValue,
              let source = FinancialSnapshotSource(rawValue: raw)
        else {
            return .unknown
        }
        return source
    }

    /// True when at least one live snapshot field is set. Credit cards
    /// require a balance-related field (``currentBalance`` or
    /// ``statementBalance``) to count; ``creditLimit`` alone is a
    /// profile fact, not a snapshot.
    var hasFinancialSnapshot: Bool {
        if isCreditCard {
            return currentBalance != nil
                || statementBalance != nil
                || availableCredit != nil
        }
        return currentBalance != nil
    }

    /// Whether the snapshot fields are older than the freshness window
    /// implied by ``latestSnapshotSource``. Returns `false` when no
    /// timestamp is set — callers should consult ``hasFinancialSnapshot``
    /// first to decide between "stale" and "never entered".
    func isFinancialSnapshotStale(now: Date = .now) -> Bool {
        guard let updatedAt = financialSnapshotUpdatedAt else {
            return false
        }
        return now.timeIntervalSince(updatedAt) > latestSnapshotSource.freshnessWindow
    }

    /// Signed contribution to net worth in this account's own currency.
    ///
    /// - Credit cards contribute `-currentBalance` when it is known;
    ///   `nil` balance means NomadFi has no honest answer and returns
    ///   zero. A credit *limit* is capacity, never an asset, so it is
    ///   never counted here.
    /// - Deposit/wallet/investment accounts prefer ``currentBalance``
    ///   and fall back to the legacy ``balance`` when no snapshot has
    ///   been entered yet, so Phase 0 rows keep working unchanged.
    var netWorthContribution: Double {
        if isCreditCard {
            guard let owed = currentBalance else { return 0 }
            return -owed
        }
        return currentBalance ?? balance
    }

    /// Whether this account is deliberately excluded from net-worth
    /// sums because it has no honest snapshot. Drives the "balance
    /// unknown" note on the Dashboard.
    var isExcludedFromNetWorth: Bool {
        isCreditCard && currentBalance == nil
    }

    /// Latest deposit-style balance to display in lists, preferring a
    /// typed snapshot over the legacy ``balance`` field. Returns `nil`
    /// when neither is present. Not meaningful for credit cards —
    /// callers should branch on ``isCreditCard`` first.
    var latestBalanceForDisplay: Double? {
        if let snapshot = currentBalance { return snapshot }
        if balance != 0 { return balance }
        return nil
    }
}

// MARK: - Reward helpers

extension Account {

    /// Pure value projection of the reward fields. Always safe to
    /// call — missing fields fall back to calm defaults (unknown
    /// unit, empty overrides, unverified provenance). Only credit
    /// cards are expected to populate this in practice; non-credit
    /// callers get the same empty profile.
    var rewardProfile: RewardProfile {
        let unit = RewardUnit.fromRawValue(rewardUnitRawValue)
        let overrides = RewardProfile.decodedCategoryOverrides(
            rewardCategoryOverridesRaw
        )
        return RewardProfile(
            programName: rewardProgramName ?? "",
            unit: unit,
            baseRate: baseRewardRate,
            categoryOverrides: overrides,
            provenance: rewardProvenance,
            notes: rewardSourceNotes ?? ""
        )
    }

    /// ``SourceProvenance`` reconstructed from the reward provenance
    /// fields. Mirrors ``foreignTransactionFeeProvenance`` so the
    /// same ``SourceFreshness`` gates apply.
    var rewardProvenance: SourceProvenance {
        let confidence = rewardSourceConfidenceRaw
            .flatMap(SourceConfidence.init(rawValue:))
            ?? .userProvided

        let scope = JurisdictionScope(countryCode: jurisdiction)

        if let name = rewardSourceName, !name.isEmpty {
            return SourceProvenance(
                name: name,
                urlString: rewardSourceURL,
                type: confidence.isVerified ? .issuerDisclosure : .userEntered,
                confidence: confidence,
                jurisdiction: scope,
                accessedAt: rewardSourceVerifiedAt,
                publishedAt: nil,
                notes: rewardSourceNotes
            )
        }

        var provenance = RewardProfile.unverifiedUserEntered
        provenance.jurisdiction = scope
        provenance.accessedAt = rewardSourceVerifiedAt
        if let notes = rewardSourceNotes, !notes.isEmpty {
            provenance.notes = notes
        }
        return provenance
    }

    /// Builds a ``RewardRateEvaluation`` for `category` and `now`.
    /// The engine (and tests) consume this rather than poking
    /// individual fields — it keeps the gating logic (freshness,
    /// unit known, rate present, category override present) in one
    /// place.
    func evaluateReward(
        for category: MerchantCategory,
        now: Date = .now
    ) -> RewardRateEvaluation {
        let profile = rewardProfile

        guard profile.hasAnyRate else {
            return .empty
        }
        guard profile.unit != .unknown else {
            return .empty
        }

        let override = profile.categoryOverrides[category]
        let rate = override ?? profile.baseRate

        let effective = SourceFreshness.effectiveConfidence(
            for: profile.provenance,
            domain: .issuerCardTerms,
            now: now
        )
        let isVerifiedAndFresh = effective.isVerified

        let explanation: String?
        if let rate, rate > 0, let suffix = profile.unit.valueSuffix {
            let formattedRate = rate.formatted(
                .number.precision(.fractionLength(0...2))
            )
            let categoryClause = override == nil
                ? "base rate"
                : "\(category.displayLabel.lowercased()) category override"
            if isVerifiedAndFresh {
                explanation = "\(formattedRate)\(suffix) — \(categoryClause), verified against \(profile.provenance.name)."
            } else {
                explanation = "\(formattedRate)\(suffix) — \(categoryClause), source not verified or outside the freshness window. NomadFi will not rank on this rate until you confirm it against the issuer's current product page."
            }
        } else {
            explanation = nil
        }

        return RewardRateEvaluation(
            rate: rate,
            unit: profile.unit,
            effectiveConfidence: effective,
            isVerifiedAndFresh: isVerifiedAndFresh,
            categoryOverrideApplied: override != nil,
            explanation: explanation
        )
    }
}

// MARK: - Display labels

extension Account {

    /// Primary line shown in account list rows.
    ///
    /// Credit cards lead with the amount owed, falling back to a
    /// "balance not set" label when no snapshot exists — never the
    /// credit limit, which is capacity, not a balance. Non-credit
    /// accounts show the latest deposit balance.
    var primaryAmountLabel: AccountAmountLabel {
        let code = currencyCodeRawValue

        if isCreditCard {
            if let owed = currentBalance {
                return AccountAmountLabel(
                    kind: .currentBalance,
                    text: "Owed \(owed.formatted(.money(code: code)))",
                    rawAmount: owed
                )
            }
            return AccountAmountLabel(
                kind: .balanceUnknown,
                text: "Balance not set",
                rawAmount: nil
            )
        }

        if let amount = latestBalanceForDisplay {
            return AccountAmountLabel(
                kind: .currentBalance,
                text: amount.formatted(.money(code: code)),
                rawAmount: amount
            )
        }

        return AccountAmountLabel(
            kind: .balanceUnknown,
            text: "Balance not set",
            rawAmount: nil
        )
    }

    /// Secondary line shown alongside ``primaryAmountLabel``.
    ///
    /// For credit cards this is the credit limit when known; nil
    /// otherwise. For non-credit accounts the row-level UI prefers
    /// other metadata (account type), so this returns nil.
    var secondaryAmountLabel: AccountAmountLabel? {
        guard isCreditCard else { return nil }
        guard let limit = creditLimit else { return nil }
        let code = currencyCodeRawValue
        return AccountAmountLabel(
            kind: .creditLimit,
            text: "Limit \(limit.formatted(.money(code: code)))",
            rawAmount: limit
        )
    }
}

/// A single amount line ready to be rendered in a row.
///
/// Keeping the label's *kind* separate from its rendered text lets
/// callers attach differentiating styling, accessibility phrasing, or
/// analytics without re-parsing the string.
struct AccountAmountLabel: Equatable, Sendable {

    enum Kind: String, Sendable {
        case creditLimit
        case currentBalance
        case availableCredit
        case statementBalance
        case balanceUnknown
    }

    let kind: Kind
    let text: String
    let rawAmount: Double?

    /// VoiceOver phrasing that never calls a credit limit a balance.
    var accessibilityPhrase: String {
        switch kind {
        case .creditLimit:
            return "credit limit \(text.replacingOccurrences(of: "Limit ", with: ""))"
        case .currentBalance:
            return "current balance \(text.replacingOccurrences(of: "Owed ", with: ""))"
        case .availableCredit:
            return "available credit \(text)"
        case .statementBalance:
            return "statement balance \(text)"
        case .balanceUnknown:
            return "balance not set"
        }
    }
}
