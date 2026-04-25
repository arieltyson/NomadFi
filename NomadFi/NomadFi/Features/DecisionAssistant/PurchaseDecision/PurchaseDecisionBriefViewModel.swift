// PurchaseDecisionBriefViewModel.swift
// NomadFi
//
// Drives the generic purchase-decision sheet. Keeps form parsing
// (amount text -> `Double?`) and engine re-runs out of the view so
// both the disabled states and the decision payload are
// unit-testable.
//
// Crash-safety note (incident learning):
//   The view model used to hold a strong `let record` reference to
//   a SwiftData `@Model` instance. Under iOS 26, an unrelated save
//   on the same context can destroy that instance, and any
//   subsequent property access traps with `"This model instance was
//   destroyed by calling ModelContext.reset and is no longer
//   usable."`. The fix mirrors the one in
//   `ScenarioDecisionBriefViewModel`: store the
//   `PersistentIdentifier` + a context, then re-resolve via
//   `ModelContext.registeredModel(for:)` on every access, falling
//   back to a stable-ID re-fetch when the row is no longer
//   registered.

import Foundation
import Observation
import OSLog
import SwiftData

/// Observable view model behind ``PurchaseDecisionBriefView``.
///
/// Re-resolves the persisted ``PurchaseDecisionRecord`` from the
/// model context on every access so a SwiftData context reset can
/// never leave the view holding a destroyed reference.
@MainActor
@Observable
final class PurchaseDecisionBriefViewModel {

    // MARK: - Persistence

    /// SwiftData context used to re-resolve `record` on every
    /// access. `nil` for previews and pure-value tests.
    private let modelContext: ModelContext?

    /// Stable identifier captured at init time when a `modelContext`
    /// was supplied. Used to round-trip back to a valid record after
    /// a context reset.
    private let recordID: PersistentIdentifier?

    /// Fallback record used when no `modelContext` was supplied.
    private let detachedRecord: PurchaseDecisionRecord

    /// The record the user is editing. Re-resolves on every access
    /// when backed by a `ModelContext`. Mutations on the returned
    /// instance persist through SwiftData's autosave on the shared
    /// context.
    var record: PurchaseDecisionRecord {
        guard let modelContext, let recordID else {
            return detachedRecord
        }
        let registered: PurchaseDecisionRecord? = modelContext
            .registeredModel(for: recordID)
        if let registered { return registered }
        return PurchaseDecisionRecord.fetchOrCreateActiveRecord(
            in: modelContext
        )
    }

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

    /// Detached initializer for previews + pure-value tests.
    convenience init(record: PurchaseDecisionRecord) {
        self.init(modelContext: nil, record: record)
    }

    /// Production initializer. Captures the `ModelContext` so the
    /// view model can survive a context reset by re-resolving the
    /// record from a stable `PersistentIdentifier`.
    init(modelContext: ModelContext?, record: PurchaseDecisionRecord) {
        self.modelContext = modelContext
        self.recordID = modelContext != nil ? record.persistentModelID : nil
        self.detachedRecord = record
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
