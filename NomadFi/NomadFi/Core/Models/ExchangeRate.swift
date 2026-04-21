import Foundation
import SwiftData

@Model
final class ExchangeRate {
    var baseCurrencyRawValue: String = CurrencyCode.usd.rawValue
    var targetCurrencyRawValue: String = CurrencyCode.cad.rawValue
    var rate: Double = 0
    var fetchedAt: Date = Date.now

    // Persisted provenance. Primitive, CloudKit-safe fields so SwiftData
    // can migrate stores created before source-governance existed.
    var sourceName: String? = nil
    var sourceURL: String? = nil
    var sourceTypeRawValue: String? = nil
    var sourceConfidenceRawValue: String? = nil
    var sourceJurisdictionRawValue: String? = nil
    var sourceAccessedAt: Date? = nil
    var sourcePublishedAt: Date? = nil
    var sourceNotes: String? = nil

    var baseCurrency: CurrencyCode? {
        CurrencyCode(rawValue: baseCurrencyRawValue)
    }

    var targetCurrency: CurrencyCode? {
        CurrencyCode(rawValue: targetCurrencyRawValue)
    }

    var pairDisplayName: String {
        "\(baseCurrencyRawValue) -> \(targetCurrencyRawValue)"
    }

    /// Reconstructs a ``SourceProvenance`` from the persisted primitives.
    ///
    /// Persisted rates from before provenance existed have no source
    /// name; they read back as `.unverified` with an unknown jurisdiction
    /// so callers do not mistake them for verified data.
    var sourceProvenance: SourceProvenance {
        let type = sourceTypeRawValue
            .flatMap(SourceType.init(rawValue:))
            ?? .unknown
        let confidence = sourceConfidenceRawValue
            .flatMap(SourceConfidence.init(rawValue:))
            ?? .unverified
        let scope = sourceJurisdictionRawValue
            .flatMap(JurisdictionScope.init(rawValue:))
            ?? .unknown

        return SourceProvenance(
            name: sourceName ?? "Unverified exchange rate",
            urlString: sourceURL,
            type: type,
            confidence: confidence,
            jurisdiction: scope,
            accessedAt: sourceAccessedAt ?? fetchedAt,
            publishedAt: sourcePublishedAt,
            notes: sourceNotes
        )
    }

    init(
        baseCurrency: CurrencyCode = .usd,
        targetCurrency: CurrencyCode = .cad,
        rate: Double = 0,
        fetchedAt: Date = .now,
        sourceName: String? = nil,
        sourceURL: String? = nil,
        sourceType: SourceType? = nil,
        sourceConfidence: SourceConfidence? = nil,
        sourceJurisdiction: JurisdictionScope? = nil,
        sourceAccessedAt: Date? = nil,
        sourcePublishedAt: Date? = nil,
        sourceNotes: String? = nil
    ) {
        self.baseCurrencyRawValue = baseCurrency.rawValue
        self.targetCurrencyRawValue = targetCurrency.rawValue
        self.rate = rate
        self.fetchedAt = fetchedAt
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceTypeRawValue = sourceType?.rawValue
        self.sourceConfidenceRawValue = sourceConfidence?.rawValue
        self.sourceJurisdictionRawValue = sourceJurisdiction?.rawValue
        self.sourceAccessedAt = sourceAccessedAt
        self.sourcePublishedAt = sourcePublishedAt
        self.sourceNotes = sourceNotes
    }

    /// Creates a persisted `ExchangeRate` from an in-memory snapshot while
    /// preserving its provenance.
    convenience init(snapshot: ExchangeRateSnapshot) {
        let provenance = snapshot.sourceProvenance
        self.init(
            baseCurrency: snapshot.baseCurrency,
            targetCurrency: snapshot.targetCurrency,
            rate: snapshot.rate,
            fetchedAt: snapshot.fetchedAt,
            sourceName: provenance.name,
            sourceURL: provenance.urlString,
            sourceType: provenance.type,
            sourceConfidence: provenance.confidence,
            sourceJurisdiction: provenance.jurisdiction,
            sourceAccessedAt: provenance.accessedAt ?? snapshot.fetchedAt,
            sourcePublishedAt: provenance.publishedAt,
            sourceNotes: provenance.notes
        )
    }
}
