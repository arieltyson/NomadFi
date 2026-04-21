import Foundation
import SwiftData

@Model
final class Transaction {
    var merchantName: String = ""
    var originalAmount: Double = 0
    var originalCurrencyRawValue: String = CurrencyCode.usd.rawValue
    var convertedAmount: Double = 0
    var homeCurrencyRawValue: String = CurrencyCode.usd.rawValue
    var appliedExchangeRate: Double = 0
    var midMarketRate: Double = 0
    var date: Date = Date.now
    var categoryRawValue: String = TransactionCategory.other.rawValue
    var jurisdiction: String = ""
    var notes: String = ""
    var isTaxDeductible: Bool = false
    var isFinanceKitImported: Bool = false
    var createdAt: Date = Date.now

    // Provenance for `appliedExchangeRate`. Primitive, CloudKit-safe
    // fields. Manually entered transactions default to userProvided.
    var appliedRateSourceName: String? = nil
    var appliedRateSourceURL: String? = nil
    var appliedRateSourceTypeRawValue: String? = nil
    var appliedRateSourceConfidenceRawValue: String? = nil
    var appliedRateSourceJurisdictionRawValue: String? = nil
    var appliedRateSourceAccessedAt: Date? = nil
    var appliedRateSourceNotes: String? = nil

    // Provenance for `midMarketRate`. Separate from applied because a
    // user can manually enter the applied rate while the mid-market rate
    // comes from a live FX service (or, in the current app, is copied
    // from the applied rate and therefore is user-provided).
    var midMarketRateSourceName: String? = nil
    var midMarketRateSourceURL: String? = nil
    var midMarketRateSourceTypeRawValue: String? = nil
    var midMarketRateSourceConfidenceRawValue: String? = nil
    var midMarketRateSourceJurisdictionRawValue: String? = nil
    var midMarketRateSourceAccessedAt: Date? = nil
    var midMarketRateSourceNotes: String? = nil

    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \TaxDocument.transaction)
    var taxDocument: TaxDocument?

    var originalCurrency: CurrencyCode? {
        CurrencyCode(rawValue: originalCurrencyRawValue)
    }

    var homeCurrency: CurrencyCode? {
        CurrencyCode(rawValue: homeCurrencyRawValue)
    }

    var category: TransactionCategory? {
        TransactionCategory(rawValue: categoryRawValue)
    }

    var fxMarkup: Double {
        guard midMarketRate > 0 else { return 0 }
        let fairConvertedAmount = originalAmount * midMarketRate
        return convertedAmount - fairConvertedAmount
    }

    /// Provenance for the `appliedExchangeRate` value.
    var appliedExchangeRateProvenance: SourceProvenance {
        Self.rateProvenance(
            name: appliedRateSourceName,
            urlString: appliedRateSourceURL,
            typeRaw: appliedRateSourceTypeRawValue,
            confidenceRaw: appliedRateSourceConfidenceRawValue,
            jurisdictionRaw: appliedRateSourceJurisdictionRawValue,
            accessedAt: appliedRateSourceAccessedAt,
            notes: appliedRateSourceNotes,
            fallbackNotes: "Applied exchange rate not verified against an issuer or network source."
        )
    }

    /// Provenance for the `midMarketRate` value.
    var midMarketRateProvenance: SourceProvenance {
        Self.rateProvenance(
            name: midMarketRateSourceName,
            urlString: midMarketRateSourceURL,
            typeRaw: midMarketRateSourceTypeRawValue,
            confidenceRaw: midMarketRateSourceConfidenceRawValue,
            jurisdictionRaw: midMarketRateSourceJurisdictionRawValue,
            accessedAt: midMarketRateSourceAccessedAt,
            notes: midMarketRateSourceNotes,
            fallbackNotes: "Mid-market rate not verified against a central-bank or network source."
        )
    }

    init(
        merchantName: String = "",
        originalAmount: Double = 0,
        originalCurrency: CurrencyCode = .usd,
        convertedAmount: Double = 0,
        homeCurrency: CurrencyCode = .usd,
        appliedExchangeRate: Double = 0,
        midMarketRate: Double = 0,
        date: Date = .now,
        category: TransactionCategory = .other,
        jurisdiction: String = "",
        notes: String = "",
        isTaxDeductible: Bool = false,
        isFinanceKitImported: Bool = false,
        createdAt: Date = .now,
        appliedRateProvenance: SourceProvenance? = nil,
        midMarketRateProvenance: SourceProvenance? = nil,
        account: Account? = nil,
        taxDocument: TaxDocument? = nil
    ) {
        self.merchantName = merchantName
        self.originalAmount = originalAmount
        self.originalCurrencyRawValue = originalCurrency.rawValue
        self.convertedAmount = convertedAmount
        self.homeCurrencyRawValue = homeCurrency.rawValue
        self.appliedExchangeRate = appliedExchangeRate
        self.midMarketRate = midMarketRate
        self.date = date
        self.categoryRawValue = category.rawValue
        self.jurisdiction = jurisdiction
        self.notes = notes
        self.isTaxDeductible = isTaxDeductible
        self.isFinanceKitImported = isFinanceKitImported
        self.createdAt = createdAt
        self.account = account
        self.taxDocument = taxDocument

        if let applied = appliedRateProvenance {
            self.appliedRateSourceName = applied.name
            self.appliedRateSourceURL = applied.urlString
            self.appliedRateSourceTypeRawValue = applied.type.rawValue
            self.appliedRateSourceConfidenceRawValue = applied.confidence.rawValue
            self.appliedRateSourceJurisdictionRawValue = applied.jurisdiction.rawValue
            self.appliedRateSourceAccessedAt = applied.accessedAt
            self.appliedRateSourceNotes = applied.notes
        }

        if let mid = midMarketRateProvenance {
            self.midMarketRateSourceName = mid.name
            self.midMarketRateSourceURL = mid.urlString
            self.midMarketRateSourceTypeRawValue = mid.type.rawValue
            self.midMarketRateSourceConfidenceRawValue = mid.confidence.rawValue
            self.midMarketRateSourceJurisdictionRawValue = mid.jurisdiction.rawValue
            self.midMarketRateSourceAccessedAt = mid.accessedAt
            self.midMarketRateSourceNotes = mid.notes
        }
    }

    /// Shared reconstruction of a rate's provenance from primitive fields.
    /// Missing or unrecognized values collapse to `.unverified` so persisted
    /// rates never read as certain without an explicit upgrade.
    private static func rateProvenance(
        name: String?,
        urlString: String?,
        typeRaw: String?,
        confidenceRaw: String?,
        jurisdictionRaw: String?,
        accessedAt: Date?,
        notes: String?,
        fallbackNotes: String
    ) -> SourceProvenance {
        let type = typeRaw.flatMap(SourceType.init(rawValue:)) ?? .unknown
        let confidence = confidenceRaw.flatMap(SourceConfidence.init(rawValue:)) ?? .unverified
        let scope = jurisdictionRaw.flatMap(JurisdictionScope.init(rawValue:)) ?? .unknown

        return SourceProvenance(
            name: (name?.isEmpty == false ? name : nil) ?? "Unverified rate",
            urlString: urlString,
            type: type,
            confidence: confidence,
            jurisdiction: scope,
            accessedAt: accessedAt,
            publishedAt: nil,
            notes: notes ?? fallbackNotes
        )
    }
}

// MARK: - Stock Provenance for manual entry

extension SourceProvenance {

    /// Provenance for an applied exchange rate derived from the amounts a
    /// user typed into `AddTransactionView`. Treated as `.userProvided` —
    /// it is what the user actually paid, not a verified market rate.
    static func manuallyEnteredAppliedRate(accessedAt: Date? = nil) -> SourceProvenance {
        SourceProvenance(
            name: "Derived from user-entered amounts",
            urlString: nil,
            type: .userEntered,
            confidence: .userProvided,
            jurisdiction: .unknown,
            accessedAt: accessedAt,
            notes: "Computed as converted ÷ original during manual entry."
        )
    }

    /// Provenance for a mid-market rate copied from the calculated applied
    /// rate during manual entry. Not an independent market rate, so it is
    /// marked `.unverified`.
    static func manuallyEnteredMidMarketRate(accessedAt: Date? = nil) -> SourceProvenance {
        SourceProvenance(
            name: "Copied from calculated applied rate",
            urlString: nil,
            type: .userEntered,
            confidence: .unverified,
            jurisdiction: .unknown,
            accessedAt: accessedAt,
            notes: "No independent market source captured at entry time; FX waste based on this value is indicative only."
        )
    }
}
