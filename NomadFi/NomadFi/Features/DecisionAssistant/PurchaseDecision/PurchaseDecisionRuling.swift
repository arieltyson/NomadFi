// PurchaseDecisionRuling.swift
// NomadFi
//
// Top-level ruling for the generic purchase engine. Derived from
// the best per-account stance so the Decision Assistant surface
// summarises the whole ranking in a single honest sentence.

import Foundation

/// Portfolio-level summary of the generic purchase engine's output.
enum PurchaseDecisionRuling: String, Sendable, Equatable, CaseIterable {

    /// User has not entered enough purchase context yet — typically
    /// no amount. The engine refuses to rank without an anchor.
    case needsPurchaseContext

    /// User has no non-investment accounts on file. Nothing to rank.
    case noPaymentAccountsOnFile

    /// At least one account is missing profile or snapshot data —
    /// and no candidate clears every guardrail. The UI surfaces the
    /// missing-data checklist.
    case missingCardData

    /// Every eligible account is blocked (insufficient funds,
    /// insufficient credit coverage, stale snapshot, etc.) even
    /// though profile data is complete.
    case allAccountsBlocked

    /// A candidate account clears every hard guardrail and is
    /// promoted as the recommended payment method for the purchase.
    case ready

    // MARK: - Display

    /// One-line ruling used on the Decision Assistant hero.
    var displaySummary: String {
        switch self {
        case .needsPurchaseContext:
            "Enter the merchant, category, and amount to rank your payment methods."
        case .noPaymentAccountsOnFile:
            "Add a checking, credit-card, or wallet account in Settings to use this engine."
        case .missingCardData:
            "NomadFi needs more account data before it can rank this purchase. Open the brief to see what's missing."
        case .allAccountsBlocked:
            "No account on file clears the guardrails for this purchase. Open the brief to see the caveats."
        case .ready:
            "A recommended payment method is available for this purchase. Open the brief for the rationale."
        }
    }
}
