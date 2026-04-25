// PurchaseContext.swift
// NomadFi
//
// The typed, sanitised input to the generic purchase decision
// engine. Nothing on this type is inferred — every field is either
// typed by the user or a safe default. The engine reads it and
// decides; the persistence layer (`PurchaseDecisionRecord`) writes it.

import Foundation

/// Pure value type describing the purchase the user is weighing.
///
/// Amount is optional so the engine can distinguish *"user has not
/// entered an amount yet"* from *"the purchase is free"* — a nil
/// amount is never silently treated as zero.
struct PurchaseContext: Sendable, Equatable {

    /// Merchant or counterparty in the user's own words. Optional
    /// for the engine — users who dictate the check via voice may
    /// leave it blank.
    let merchantName: String

    /// User-picked category. Defaults to `.general` at the
    /// persistence layer so every run has a valid category.
    let category: MerchantCategory

    /// The total the user expects to pay. `nil` means the field has
    /// not been filled in yet; `0` means "explicitly zero" (which
    /// still blocks the recommendation — the engine refuses to rank
    /// payment methods for a zero-amount purchase).
    let amount: Double?

    /// Currency the user intends to pay in at checkout (or the
    /// currency the merchant bills in).
    let currencyCode: CurrencyCode

    /// Short hint about the purchase location — "U.S. summer
    /// address", "Toronto", etc. Never a full street address; the
    /// engine surfaces privacy copy in the capture form.
    ///
    /// _Naming note:_ this field is called `countryCode` for
    /// historical persistence reasons (`PurchaseDecisionRecord`
    /// stores it under that name across CloudKit). It is not an
    /// ISO country code — the user types a free-form short hint.
    /// Engine reads should use ``locationHint`` so the intent is
    /// clear at the call site.
    let countryCode: String

    /// Urgency / timing note in the user's own words ("before the
    /// trip", "before statement close"). Never parsed into a date.
    let timingText: String

    // MARK: - Derived

    /// The engine only ranks candidates when the user has supplied
    /// enough to anchor the decision — a positive amount. The
    /// category, merchant, and location are nice-to-have.
    var hasUsableAmount: Bool {
        guard let amount else { return false }
        return amount > 0
    }

    /// Whether the user has filled in enough for the engine to
    /// produce a ruling beyond "needs purchase context".
    var isComplete: Bool {
        hasUsableAmount
    }

    /// Honest alias over ``countryCode``. Engine and signal-
    /// derivation code should read this rather than `countryCode`
    /// to keep the semantics ("free-form hint, not an ISO code")
    /// obvious at every call site.
    var locationHint: String { countryCode }

    /// Whether the user has typed a non-empty, non-whitespace
    /// location hint. Feeds ``PurchaseTravelContext``.
    var hasLocationHint: Bool {
        !locationHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
