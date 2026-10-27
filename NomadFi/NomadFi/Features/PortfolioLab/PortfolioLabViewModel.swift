// PortfolioLabViewModel.swift
// NomadFi
//
// Drives Tools → Portfolio Lab: picks the data, runs the shared engine
// off the main actor, and keeps the person's choices.

import Foundation
import OSLog

/// Where Portfolio Lab's fund prices come from.
enum PortfolioLabDataSource: String, CaseIterable, Identifiable, Sendable {
    /// Bundled illustrative prices: works offline, needs no account.
    case sample
    /// Real month-end prices from Tiingo, fetched with the person's own token.
    case live

    var id: Self { self }
}

@MainActor
@Observable
final class PortfolioLabViewModel {

    // MARK: - Choices

    var source: PortfolioLabDataSource = .sample
    var amount: Double = 5_000
    var conversionID = PortfolioLabConversionMethod.bank.id
    var profile: PortfolioLabRiskProfile = .balanced
    var expectation: PortfolioLabExpectation = .shrunkHistorical
    var includesCash = true

    // MARK: - State

    private(set) var result: PortfolioLabResult?
    private(set) var isRunning = false
    private(set) var errorMessage: String?
    /// The currency the person invests from; see ``setJurisdictions(_:)``.
    var homeCurrency: CurrencyCode?
    /// The person's currencies that Portfolio Lab can invest from, home first.
    private(set) var investableCurrencies: [CurrencyCode] = []
    /// Whether any jurisdictions have been loaded yet.
    private(set) var hasJurisdictions = false
    private(set) var hasToken: Bool

    let snapshot: PortfolioLabFXSnapshot?
    let sampleNote: String?

    /// Currencies the published FX history can convert between.
    static let supportedCurrencies: Set<CurrencyCode> = [.cad, .usd]
    static let cashRate = 0.02
    static let amountRange: ClosedRange<Double> = 100...1_000_000

    // MARK: - Dependencies

    private let priceService: any PortfolioLabPriceService
    private let tokenStore: TokenStore
    private let sample: PortfolioLabSampleMarket?
    private var liveSeries: [PortfolioLabPriceSeries]?

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "PortfolioLab")

    /// Reads and writes the Tiingo token, so tests never touch the Keychain.
    struct TokenStore: Sendable {
        var load: @Sendable () -> String?
        var save: @Sendable (String) -> Bool
        var delete: @Sendable () -> Void

        static let keychain = TokenStore(
            load: { KeychainService.loadString(forKey: .tiingoAPIToken) },
            save: { KeychainService.save($0, forKey: .tiingoAPIToken) },
            delete: { _ = KeychainService.delete(key: .tiingoAPIToken) }
        )
    }

    init(
        priceService: any PortfolioLabPriceService = TiingoPriceService(),
        tokenStore: TokenStore = .keychain,
        bundle: Bundle = .main
    ) {
        self.priceService = priceService
        self.tokenStore = tokenStore
        snapshot = try? PortfolioLabResources.fxSnapshot(in: bundle)
        sample = try? PortfolioLabResources.sampleMarket(in: bundle)
        sampleNote = sample?.note
        hasToken = !(tokenStore.load() ?? "").isEmpty
    }

    // MARK: - Derived

    var conversionMethods: [PortfolioLabConversionMethod] {
        snapshot?.conversionMethods ?? PortfolioLabConversionMethod.standard
    }

    var conversion: PortfolioLabConversionMethod {
        conversionMethods.first { $0.id == conversionID } ?? .bank
    }

    var isHomeCurrencySupported: Bool {
        homeCurrency.map(Self.supportedCurrencies.contains) ?? false
    }

    /// True once jurisdictions are known and none of them uses CAD or USD.
    var lacksSupportedCurrency: Bool {
        hasJurisdictions && investableCurrencies.isEmpty
    }

    /// The cheapest way to convert, compared with the chosen one, after the backtest.
    var cheapestComparison: PortfolioLabScenario? {
        result?.comparisons.max { $0.backtest.endingValue < $1.backtest.endingValue }
    }

    // MARK: - Running

    /// Invests from the home currency when the FX history covers it, otherwise from
    /// the first covered currency among the person's other jurisdictions, so someone
    /// whose home is Trinidad and Tobago but who studies in Canada invests in CAD.
    func setJurisdictions(_ jurisdictions: [JurisdictionProfile]) {
        let ordered = jurisdictions.filter(\.isHome) + jurisdictions.filter { !$0.isHome }
        var seen = Set<CurrencyCode>()
        investableCurrencies = ordered.compactMap(\.currencyCode).filter {
            Self.supportedCurrencies.contains($0) && seen.insert($0).inserted
        }
        hasJurisdictions = !jurisdictions.isEmpty
        if homeCurrency.map(investableCurrencies.contains) != true {
            homeCurrency = investableCurrencies.first
        }
    }

    /// Recomputes the result for the current choices.
    func run() async {
        guard let homeCurrency, isHomeCurrencySupported, let snapshot else {
            result = nil
            return
        }
        isRunning = result == nil
        defer { isRunning = false }
        do {
            let series = try await prices()
            let request = PortfolioLabRequest(
                series: series,
                fx: snapshot.fx,
                homeCurrency: homeCurrency.rawValue,
                amount: min(max(amount, Self.amountRange.lowerBound), Self.amountRange.upperBound),
                conversion: conversion,
                comparedConversions: conversionMethods,
                profile: profile,
                expectation: expectation,
                cashRate: includesCash ? Self.cashRate : nil
            )
            result = try await Task.detached(priority: .userInitiated) { try PortfolioLabEngine.run(request) }.value
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as PortfolioLabPriceServiceError {
            result = nil
            errorMessage = error.localizedDescription
        } catch PortfolioLabError.insufficientHistory(let months) {
            result = nil
            errorMessage = String(localized: "Only \(months) months of overlapping prices are available. Portfolio Lab needs at least two years.")
        } catch {
            result = nil
            errorMessage = String(localized: "Portfolio Lab couldn't run with this data.")
            Self.logger.error("Portfolio Lab failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Token

    /// Stores a token that looks like one; Tiingo tokens are hexadecimal.
    @discardableResult
    func saveToken(_ raw: String) -> Bool {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isPlausibleToken(token), tokenStore.save(token) else { return false }
        hasToken = true
        liveSeries = nil
        return true
    }

    func removeToken() {
        tokenStore.delete()
        hasToken = false
        liveSeries = nil
        if source == .live { source = .sample }
    }

    nonisolated static func isPlausibleToken(_ token: String) -> Bool {
        (20...64).contains(token.count) && token.allSatisfy(\.isHexDigit)
    }

    // MARK: - Private

    private func prices() async throws -> [PortfolioLabPriceSeries] {
        switch source {
        case .sample:
            guard let sample else { throw PortfolioLabResources.LoadError.missing("sample-market") }
            return sample.series
        case .live:
            if let liveSeries { return liveSeries }
            guard hasToken else { throw PortfolioLabPriceServiceError.missingToken }
            let since = snapshot?.fx.points.first?.month ?? "2017-01"
            let fetched = try await priceService.monthlyCloses(for: PortfolioLabLiveCatalog.funds, since: since)
            liveSeries = fetched
            return fetched
        }
    }
}
