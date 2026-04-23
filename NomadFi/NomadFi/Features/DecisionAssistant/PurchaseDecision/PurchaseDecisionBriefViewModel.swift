// PurchaseDecisionBriefViewModel.swift
// NomadFi
//
// Drives the generic purchase-decision sheet. Keeps form parsing
// (amount text -> `Double?`) and engine re-runs out of the view so
// both the disabled states and the decision payload are
// unit-testable.

import Foundation
import Observation
import OSLog
import SwiftData

/// Observable view model behind ``PurchaseDecisionBriefView``.
///
/// Owns a live reference to the persisted ``PurchaseDecisionRecord``
/// and mirrors its fields as form state. Mutations flow through the
/// view model so trimming and amount parsing happen in one place.
@MainActor
@Observable
final class PurchaseDecisionBriefViewModel {

    // MARK: - Persistence

    /// The record the user is editing. Mutations here persist
    /// through SwiftData's autosave on the shared `ModelContext`.
    let record: PurchaseDecisionRecord

    // MARK: - Form state

    /// Decimal-pad-friendly string the amount field binds to. The
    /// view model converts this to `Double?` on save.
    var amountText: String

    // MARK: - Dependencies

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "PurchaseDecisionBrief"
    )

    // MARK: - Init

    init(record: PurchaseDecisionRecord) {
        self.record = record
        self.amountText = Self.amountEditingText(for: record.amount)
    }

    // MARK: - Mutations

    /// Writes trimmed text through to the record and stamps
    /// `updatedAt`. Called from the view on every bindable edit —
    /// cheap because the engine is pure and runs off computed
    /// properties below.
    func commitTextEdits(now: Date = .now) {
        record.merchantName = record.merchantName.trimmingCharacters(in: .whitespaces)
        record.countryCode = record.countryCode.trimmingCharacters(in: .whitespaces)
        record.timingText = record.timingText.trimmingCharacters(in: .whitespaces)
        record.updatedAt = now
    }

    /// Parses ``amountText`` and writes the result onto the record.
    /// Stamps `updatedAt`. Empty text clears the amount — the engine
    /// will fall back to `.needsPurchaseContext` until a value comes in.
    func commitAmountEdit(now: Date = .now) {
        record.amount = Self.parseAmount(amountText)
        record.updatedAt = now
    }

    /// Updates the category raw value and stamps `updatedAt`.
    func setCategory(_ category: MerchantCategory, now: Date = .now) {
        record.categoryRawValue = category.rawValue
        record.updatedAt = now
    }

    /// Updates the currency and stamps `updatedAt`.
    func setCurrencyCode(_ currency: CurrencyCode, now: Date = .now) {
        record.currencyCodeRawValue = currency.rawValue
        record.updatedAt = now
    }

    // MARK: - Derived

    /// Re-runs the engine against the supplied accounts. The view
    /// calls this from a computed property so every bindable edit
    /// reactively refreshes the result.
    func decision(
        accounts: [Account],
        now: Date = .now
    ) -> PurchaseDecision {
        PurchaseDecisionEngine.decide(
            context: record.context,
            accounts: accounts,
            now: now
        )
    }

    // MARK: - Helpers

    /// Parses a locale-aware decimal string into a `Double?`. Empty
    /// strings and strings that can't be parsed return `nil` — never
    /// silently 0.
    static func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let direct = Double(trimmed) { return direct }

        if let localeDecimal = Decimal(string: trimmed, locale: .current) {
            return NSDecimalNumber(decimal: localeDecimal).doubleValue
        }
        return nil
    }

    /// Formats a stored amount back into the text the `.decimalPad`
    /// field expects. Drops the trailing `.0` on whole numbers.
    static func amountEditingText(for amount: Double?) -> String {
        guard let amount else { return "" }
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(amount))
        }
        return String(amount)
    }
}
