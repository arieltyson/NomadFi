// PurchaseDecisionRecord.swift
// NomadFi
//
// Persisted user-facing inputs for the active generic purchase
// check. One row per install — opening the sheet materialises (or
// re-opens) this record so the user's last typed purchase sticks
// across launches.
//
// CloudKit-safe by construction:
//   - No `@Attribute(.unique)`.
//   - Every property has a default or is optional.
//   - No relationships.
//
// Privacy: purchase drafts never carry card numbers, account
// numbers, SSNs, SINs, or full street addresses. The capture form
// surfaces this constraint to the user; the model enforces it by
// simply not having fields for such values.

import Foundation
import SwiftData

/// Persisted active purchase-decision record. Stores exactly the
/// ``PurchaseContext`` fields the engine needs, plus timestamps for
/// the UI's "last updated" label and the fetch-or-create bootstrap.
@Model
final class PurchaseDecisionRecord {

    /// Stable identifier. Application code uniqueness is preserved
    /// by ``activeRecordID`` rather than an `@Attribute(.unique)`
    /// annotation that would break CloudKit sync.
    var recordID: UUID = UUID()

    /// Uniqueness anchor. Fetching with this string returns the
    /// active record; new installs create a fresh row with the same
    /// anchor.
    var scenarioID: String = ""

    // MARK: - Purchase context

    /// Merchant or counterparty in the user's own words.
    var merchantName: String = ""

    /// Raw value of ``MerchantCategory``. Persisted as a String so
    /// future enum additions don't drive a CloudKit migration.
    var categoryRawValue: String = MerchantCategory.general.rawValue

    /// User-entered total they expect to pay. `nil` means the field
    /// has not been filled in — the engine refuses to rank on a nil
    /// amount.
    var amount: Double?

    /// Raw value of ``CurrencyCode`` for the purchase.
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue

    /// Short location hint — city or country, never a full street
    /// address.
    var countryCode: String = ""

    /// User-written timing note ("before the trip"). Not parsed into
    /// a Date.
    var timingText: String = ""

    // MARK: - Lifecycle

    /// Stamped at insertion. Never mutated after.
    var createdAt: Date = Date.now

    /// Refreshed whenever the user edits any input.
    var updatedAt: Date = Date.now

    // MARK: - Init

    init(
        recordID: UUID = UUID(),
        scenarioID: String = "",
        merchantName: String = "",
        category: MerchantCategory = .general,
        amount: Double? = nil,
        currencyCode: CurrencyCode = .usd,
        countryCode: String = "",
        timingText: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.recordID = recordID
        self.scenarioID = scenarioID
        self.merchantName = merchantName
        self.categoryRawValue = category.rawValue
        self.amount = amount
        self.currencyCodeRawValue = currencyCode.rawValue
        self.countryCode = countryCode
        self.timingText = timingText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Identifiers

extension PurchaseDecisionRecord {

    /// Single stable anchor used by the fetch-or-create bootstrap.
    static let activeRecordID: String = "purchase-decision-active-v1"
}

// MARK: - Derived

extension PurchaseDecisionRecord {

    /// Typed ``MerchantCategory`` view over ``categoryRawValue``.
    /// Falls back to `.general` for unknown raw values so a schema
    /// drift never crashes the UI.
    var category: MerchantCategory {
        MerchantCategory(rawValue: categoryRawValue) ?? .general
    }

    /// Typed ``CurrencyCode`` view over ``currencyCodeRawValue``.
    var currencyCode: CurrencyCode {
        CurrencyCode(rawValue: currencyCodeRawValue) ?? .usd
    }

    /// Pure projection the engine consumes.
    var context: PurchaseContext {
        PurchaseContext(
            merchantName: merchantName,
            category: category,
            amount: amount,
            currencyCode: currencyCode,
            countryCode: countryCode,
            timingText: timingText
        )
    }

    /// Whether the record has enough context for the engine to rank.
    var hasUsableContext: Bool {
        context.isComplete
    }
}

// MARK: - Bootstrap

extension PurchaseDecisionRecord {

    /// Fetches the singleton active purchase record, creating and
    /// inserting a fresh one if none exists. Mirrors the pattern
    /// `ScenarioDecisionBriefViewModel` uses for Scenario 1.
    @MainActor
    static func fetchOrCreateActiveRecord(
        in modelContext: ModelContext
    ) -> PurchaseDecisionRecord {
        let anchor = activeRecordID
        var descriptor = FetchDescriptor<PurchaseDecisionRecord>(
            predicate: #Predicate { $0.scenarioID == anchor }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let fresh = PurchaseDecisionRecord(scenarioID: anchor)
        modelContext.insert(fresh)
        try? modelContext.save()
        return fresh
    }
}
