// DecisionDraftNextAction.swift
// NomadFi
//
// One labeled, calm next step the user can take with a captured
// draft. Pure value type so the evaluator, detail view, and tests
// share one source of truth for labels and SF Symbols. Each case
// either:
//
//   • routes the user — explicitly — into an existing deterministic
//     engine (purchase-card check, credit-timing check), or
//   • points the user at an in-app source-backed surface (Tax Vault,
//     Investing Learn), or
//   • surfaces a procedural reminder when no engine fits today.
//
// The cases never claim a recommendation — that is reserved for the
// engines themselves. A draft can never be auto-analyzed; the user
// taps the action button to opt in.

import Foundation

/// Discriminated union over the next-step buttons / labels the
/// detail view can render for a draft.
enum DecisionDraftNextAction: Sendable, Equatable, Hashable, Identifiable {

    /// Open the existing generic Purchase Decision brief, prefilled
    /// from the draft's captured fields. The user must still confirm
    /// before NomadFi finalises a recommendation.
    case openPurchaseCheck

    /// Open the existing Credit Timing brief. Reads the user's
    /// saved credit cards live — no prefill needed.
    case openCreditTimingCheck

    /// Calm, non-deep-link reminder that the related source-backed
    /// surface lives at Tools → Tax Vault.
    case reviewInTaxVault

    /// Calm, non-deep-link reminder that the related source-backed
    /// surface lives at Tools → Investing Learn.
    case reviewInInvestingLearn

    /// Procedural reminder to add a missing structured field
    /// (amount, currency, etc.) before NomadFi can hand off.
    case addContext(field: MissingContextField)

    /// Procedural reminder that NomadFi has no deterministic engine
    /// for this draft kind today. Never paired with a route.
    case noEngineYet

    var id: String { rawIdentifier }

    /// Stable identifier used for `ForEach` keys — derived from the
    /// case so the evaluator can emit two `addContext` actions with
    /// distinct fields and have them render distinctly.
    var rawIdentifier: String {
        switch self {
        case .openPurchaseCheck: "open-purchase-check"
        case .openCreditTimingCheck: "open-credit-timing-check"
        case .reviewInTaxVault: "review-in-tax-vault"
        case .reviewInInvestingLearn: "review-in-investing-learn"
        case .addContext(let field): "add-context-\(field.rawValue)"
        case .noEngineYet: "no-engine-yet"
        }
    }

    // MARK: - Display

    /// Imperative, narrow label rendered on the action button (or
    /// label, for the `.noEngineYet` and `.reviewIn…` cases). Never
    /// claims a recommendation.
    var displayLabel: String {
        switch self {
        case .openPurchaseCheck:
            "Open purchase check"
        case .openCreditTimingCheck:
            "Open credit timing check"
        case .reviewInTaxVault:
            "Review in Tax Vault"
        case .reviewInInvestingLearn:
            "Review in Investing Learn"
        case .addContext(let field):
            field.actionLabel
        case .noEngineYet:
            "No deterministic engine for this draft kind yet"
        }
    }

    /// SF Symbol paired with the label.
    var systemImage: String {
        switch self {
        case .openPurchaseCheck: "creditcard.and.123"
        case .openCreditTimingCheck: "calendar.badge.clock"
        case .reviewInTaxVault: "doc.text.viewfinder"
        case .reviewInInvestingLearn: "books.vertical"
        case .addContext: "questionmark.circle"
        case .noEngineYet: "hourglass"
        }
    }

    /// `true` when the action is one the user can tap to hand off
    /// into an existing deterministic engine. Used by the detail
    /// view to render a `Button` for the actionable cases and a
    /// plain `Label` for the procedural reminders.
    var isHandoff: Bool {
        switch self {
        case .openPurchaseCheck, .openCreditTimingCheck:
            true
        case .reviewInTaxVault, .reviewInInvestingLearn,
             .addContext, .noEngineYet:
            false
        }
    }

    /// Voice-friendly hint for assistive readers.
    var accessibilityHint: String {
        switch self {
        case .openPurchaseCheck:
            "Opens the existing Purchase Card Check brief, prefilled from this draft. NomadFi does not finalise a recommendation until you review the brief."
        case .openCreditTimingCheck:
            "Opens the existing Credit Timing Check brief. NomadFi reads your saved credit cards live."
        case .reviewInTaxVault:
            "NomadFi does not deep-link Tax Vault from this surface. Open the Tools tab, then Tax Vault."
        case .reviewInInvestingLearn:
            "NomadFi does not deep-link Investing Learn from this surface. Open the Tools tab, then Investing Learn."
        case .addContext(let field):
            field.accessibilityHint
        case .noEngineYet:
            "NomadFi has captured this draft but no deterministic engine covers this kind yet."
        }
    }
}

// MARK: - Missing context

/// Discrete set of structured fields the evaluator can ask the
/// user to add to a draft. Each case has its own copy so the
/// detail view never has to assemble strings.
enum MissingContextField: String, Sendable, Equatable, Hashable, CaseIterable {

    case amount
    case currency
    case savedCreditCard

    var actionLabel: String {
        switch self {
        case .amount: "Add an amount first"
        case .currency: "Pick a currency first"
        case .savedCreditCard: "Add a credit card in Settings → Financial Setup → Accounts"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .amount:
            "NomadFi needs a positive amount on the draft before it can hand off to the Purchase Card Check engine."
        case .currency:
            "NomadFi needs a currency on the draft before it can hand off to the Purchase Card Check engine."
        case .savedCreditCard:
            "NomadFi has no credit card on file. Add one in Settings before opening the Credit Timing Check."
        }
    }
}
