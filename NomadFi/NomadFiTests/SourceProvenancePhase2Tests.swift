// SourceProvenancePhase2Tests.swift
// NomadFi
//
// Phase 2 coverage: jurisdiction mapping, persistent provenance on
// ExchangeRate and Transaction, manual-entry defaults, and freshness-aware
// downgrading via `SourceFreshness.effectiveConfidence`.

import Foundation
import Testing

@testable import NomadFi

struct SourceProvenancePhase2Tests {

    // MARK: - Jurisdiction mapping

    @Test("Country codes map to the correct JurisdictionScope")
    func countryCodeMapping() {
        #expect(JurisdictionScope(countryCode: "US") == .unitedStates)
        #expect(JurisdictionScope(countryCode: "us") == .unitedStates)
        #expect(JurisdictionScope(countryCode: "USA") == .unitedStates)
        #expect(JurisdictionScope(countryCode: "CA") == .canada)
        #expect(JurisdictionScope(countryCode: "TT") == .trinidadAndTobago)
        #expect(JurisdictionScope(countryCode: "") == .unknown)
        #expect(JurisdictionScope(countryCode: nil) == .unknown)
        #expect(JurisdictionScope(countryCode: "ZZ") == .unknown)
    }

    @Test("Account.foreignTransactionFeeProvenance uses account jurisdiction")
    func accountProvenanceUsesJurisdiction() {
        let us = Account(
            name: "Chase Freedom Rise",
            institutionName: "JPMorgan Chase",
            accountType: .creditCard,
            currencyCode: .usd,
            balance: 0,
            jurisdiction: "US",
            foreignTransactionFeePercent: 3.0
        )
        #expect(us.foreignTransactionFeeProvenance.jurisdiction == .unitedStates)

        let ca = Account(
            name: "CIBC Dividend Cash Back",
            institutionName: "CIBC",
            accountType: .creditCard,
            currencyCode: .cad,
            balance: 0,
            jurisdiction: "CA",
            foreignTransactionFeePercent: 2.5,
            foreignTransactionFeeSourceName: "CIBC Disclosure",
            foreignTransactionFeeSourceConfidence: .verifiedPrimary,
            foreignTransactionFeeSourceVerifiedAt: .now
        )
        #expect(ca.foreignTransactionFeeProvenance.jurisdiction == .canada)

        let tt = Account(
            name: "Republic Bank",
            institutionName: "Republic",
            accountType: .savings,
            currencyCode: .ttd,
            balance: 0,
            jurisdiction: "TT"
        )
        #expect(tt.foreignTransactionFeeProvenance.jurisdiction == .trinidadAndTobago)
    }

    // MARK: - ExchangeRate persistence

    @Test("ExchangeRate round-trips SourceProvenance through primitive fields")
    func exchangeRateRoundTrip() {
        let accessed = Date(timeIntervalSince1970: 1_700_000_000)
        let original = SourceProvenance(
            name: "Bank of Canada",
            urlString: "https://www.bankofcanada.ca/valet/",
            type: .centralBankDataset,
            confidence: .verifiedPrimary,
            jurisdiction: .canada,
            accessedAt: accessed,
            publishedAt: accessed,
            notes: "Daily observation"
        )

        let rate = ExchangeRate(
            baseCurrency: .usd,
            targetCurrency: .cad,
            rate: 1.36,
            fetchedAt: accessed,
            sourceName: original.name,
            sourceURL: original.urlString,
            sourceType: original.type,
            sourceConfidence: original.confidence,
            sourceJurisdiction: original.jurisdiction,
            sourceAccessedAt: original.accessedAt,
            sourcePublishedAt: original.publishedAt,
            sourceNotes: original.notes
        )

        let restored = rate.sourceProvenance
        #expect(restored.name == original.name)
        #expect(restored.urlString == original.urlString)
        #expect(restored.type == original.type)
        #expect(restored.confidence == original.confidence)
        #expect(restored.jurisdiction == original.jurisdiction)
        #expect(restored.accessedAt == original.accessedAt)
    }

    @Test("ExchangeRate(snapshot:) preserves live-service provenance")
    func exchangeRateFromSnapshot() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = ExchangeRateSnapshot(
            baseCurrency: .usd,
            targetCurrency: .ttd,
            rate: 6.78,
            fetchedAt: now,
            sourceProvenance: .openExchangeRatesAPI(accessedAt: now)
        )

        let persisted = ExchangeRate(snapshot: snapshot)
        #expect(persisted.sourceProvenance.type == .prototypeAPI)
        #expect(persisted.sourceProvenance.confidence == .indicative)
        #expect(persisted.sourceProvenance.accessedAt == now)
    }

    @Test("ExchangeRate with no stored provenance reads as unverified")
    func exchangeRateWithoutProvenanceIsUnverified() {
        let bare = ExchangeRate(baseCurrency: .usd, targetCurrency: .cad, rate: 1.36)
        #expect(bare.sourceProvenance.confidence == .unverified)
        #expect(bare.sourceProvenance.confidence.isVerified == false)
    }

    // MARK: - Transaction persistence

    @Test("Manually constructed transaction with no provenance is unverified")
    func transactionDefaultsToUnverified() {
        let txn = Transaction(
            merchantName: "Unknown",
            originalAmount: -10,
            originalCurrency: .usd,
            convertedAmount: -13.6,
            homeCurrency: .cad,
            appliedExchangeRate: 1.36,
            midMarketRate: 1.36
        )

        #expect(txn.appliedExchangeRateProvenance.confidence == .unverified)
        #expect(txn.midMarketRateProvenance.confidence == .unverified)
        #expect(txn.appliedExchangeRateProvenance.confidence.isVerified == false)
        #expect(txn.midMarketRateProvenance.confidence.isVerified == false)
    }

    @Test("AddTransactionView manual-entry provenance factories are labeled correctly")
    func manualEntryFactories() {
        let applied = SourceProvenance.manuallyEnteredAppliedRate(accessedAt: .now)
        #expect(applied.confidence == .userProvided)
        #expect(applied.type == .userEntered)

        let midMarket = SourceProvenance.manuallyEnteredMidMarketRate(accessedAt: .now)
        #expect(midMarket.confidence == .unverified)
        #expect(midMarket.type == .userEntered)
        // Mid-market copied from the calculated applied rate must not
        // ever be treated as verified.
        #expect(midMarket.confidence.isVerified == false)
    }

    @Test("Transaction initializer persists applied and mid-market provenance")
    func transactionPersistsRateProvenance() {
        let accessed = Date(timeIntervalSince1970: 1_700_100_000)
        let txn = Transaction(
            merchantName: "Test",
            originalAmount: -10,
            originalCurrency: .usd,
            convertedAmount: -13.6,
            homeCurrency: .cad,
            appliedExchangeRate: 1.36,
            midMarketRate: 1.36,
            appliedRateProvenance: .manuallyEnteredAppliedRate(accessedAt: accessed),
            midMarketRateProvenance: .manuallyEnteredMidMarketRate(accessedAt: accessed)
        )

        #expect(txn.appliedExchangeRateProvenance.confidence == .userProvided)
        #expect(txn.midMarketRateProvenance.confidence == .unverified)
        #expect(txn.appliedExchangeRateProvenance.accessedAt == accessed)
        #expect(txn.midMarketRateProvenance.accessedAt == accessed)
    }

    // MARK: - Effective confidence (freshness gating)

    @Test("Fresh verified provenance keeps its verified confidence")
    func freshVerifiedPassesThrough() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let provenance = SourceProvenance(
            name: "CIBC Disclosure",
            urlString: nil,
            type: .issuerDisclosure,
            confidence: .verifiedPrimary,
            jurisdiction: .canada,
            accessedAt: now.addingTimeInterval(-60 * 60 * 24 * 2) // 2 days ago
        )

        let effective = SourceFreshness.effectiveConfidence(
            for: provenance,
            domain: .issuerCardTerms,
            now: now
        )
        #expect(effective == .verifiedPrimary)
        #expect(effective.isVerified)
    }

    @Test("Stale verified issuer terms degrade to unverified")
    func staleVerifiedDegrades() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let provenance = SourceProvenance(
            name: "CIBC Disclosure",
            urlString: nil,
            type: .issuerDisclosure,
            confidence: .verifiedPrimary,
            jurisdiction: .canada,
            accessedAt: now.addingTimeInterval(-60 * 60 * 24 * 90) // 90 days ago
        )

        let effective = SourceFreshness.effectiveConfidence(
            for: provenance,
            domain: .issuerCardTerms,
            now: now
        )
        #expect(effective == .unverified)
        #expect(effective.isVerified == false)
    }

    @Test("Missing verification date degrades verified source to unverified")
    func missingDateDegrades() {
        let provenance = SourceProvenance(
            name: "CIBC Disclosure",
            urlString: nil,
            type: .issuerDisclosure,
            confidence: .verifiedPrimary,
            jurisdiction: .canada,
            accessedAt: nil
        )

        let effective = SourceFreshness.effectiveConfidence(
            for: provenance,
            domain: .issuerCardTerms
        )
        #expect(effective == .unverified)
    }

    @Test("Non-verified confidence passes through effectiveConfidence unchanged")
    func nonVerifiedPassesThrough() {
        let provenance = SourceProvenance.openExchangeRatesAPI(accessedAt: .now)
        let effective = SourceFreshness.effectiveConfidence(
            for: provenance,
            domain: .liveFXMarketData
        )
        // Fresh indicative is still indicative — not upgraded.
        #expect(effective == .indicative)
    }
}
