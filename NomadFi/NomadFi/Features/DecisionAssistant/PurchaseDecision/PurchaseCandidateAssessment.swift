// PurchaseCandidateAssessment.swift
// NomadFi
//
// Pure per-account output of the generic purchase engine. Renders
// as a row in the brief sheet. Carries every derived value the UI
// needs so the view never has to re-implement coverage math.

import Foundation

/// Deterministic assessment of a single account as a payment
/// method for a purchase.
struct PurchaseCandidateAssessment: Identifiable, Sendable, Equatable {

    /// Stable identifier derived from institution + account name so
    /// the value stays `Sendable` and test-friendly.
    let id: String

    /// User-facing display name.
    let accountName: String

    /// Issuer / institution.
    let institutionName: String

    /// Human-readable account-type label (e.g. "Credit Card").
    let accountTypeDisplay: String

    /// Account's own currency code.
    let currencyCode: String

    /// Whether this account's currency matches the purchase currency.
    let matchesPurchaseCurrency: Bool

    /// The engine's stance on this account.
    let stance: PurchaseCandidateStance

    /// Short reasons that back up the stance — used for the
    /// "when not to use" narrative and for VoiceOver descriptions.
    let reasons: [String]

    /// User-actionable follow-ups (e.g. "Refresh the balance snapshot").
    /// Aggregated into the portfolio checklist by the engine.
    let outstandingChecks: [String]

    // MARK: - Funds snapshot

    /// Deposit / wallet current balance, when known. `nil` means
    /// NomadFi has no honest answer.
    let currentBalance: Double?

    /// Credit-card limit, when known.
    let creditLimit: Double?

    /// Credit-card available credit — either user-entered or
    /// computed as `creditLimit - currentBalance`. `nil` when
    /// inputs are missing.
    let availableCredit: Double?

    /// Whether this account was produced by a credit-card row.
    let isCreditCard: Bool

    // MARK: - FX signal

    /// Raw foreign-transaction-fee percent from the account, when
    /// the purchase crosses currencies. `nil` when no FX friction
    /// applies.
    let foreignTransactionFeePercent: Double?

    /// Whether the FX fee is verified enough to quote confidently
    /// per ``SourceFreshness``. The engine never treats an
    /// unverified fee as verified.
    let foreignTransactionFeeIsVerified: Bool
}
