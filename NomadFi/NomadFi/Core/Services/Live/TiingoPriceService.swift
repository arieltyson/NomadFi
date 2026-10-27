// TiingoPriceService.swift
// NomadFi
//
// Month-end fund prices from Tiingo, fetched on device with the
// person's own API token.

import Foundation
import OSLog

/// Live ``PortfolioLabPriceService`` backed by Tiingo's end-of-day API.
///
/// Tiingo's developer program allows apps that require each user to
/// supply their own token, as long as Tiingo is credited wherever its
/// data is shown. The token stays in the Keychain and travels only in
/// the `Authorization` header; responses are never written to disk.
struct TiingoPriceService: PortfolioLabPriceService {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "PortfolioLab")
    private static let baseURL = URL(string: "https://api.tiingo.com/tiingo/daily/")!

    /// Tiingo's page, linked wherever its prices appear, as its terms require.
    static let attributionURL = URL(string: "https://www.tiingo.com")!
    static let signUpURL = URL(string: "https://www.tiingo.com/account/api/token")!

    private let token: @Sendable () -> String?
    private let session: URLSession
    private let pinningDelegate = CertificatePinningDelegate()

    init(token: @escaping @Sendable () -> String? = { KeychainService.loadString(forKey: .tiingoAPIToken) }) {
        self.token = token
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration, delegate: pinningDelegate, delegateQueue: nil)
    }

    func monthlyCloses(for assets: [PortfolioLabAsset], since month: String) async throws -> [PortfolioLabPriceSeries] {
        guard let token = token(), !token.isEmpty else { throw PortfolioLabPriceServiceError.missingToken }
        return try await withThrowingTaskGroup(of: (Int, PortfolioLabPriceSeries).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    let closes = try await fetch(asset.symbol, since: month, token: token)
                    return (index, PortfolioLabPriceSeries(asset: asset, closes: closes))
                }
            }
            var series: [(Int, PortfolioLabPriceSeries)] = []
            for try await item in group { series.append(item) }
            return series.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func fetch(_ symbol: String, since month: String, token: String) async throws -> [PortfolioLabClose] {
        var url = Self.baseURL.appending(path: symbol.lowercased()).appending(path: "prices")
        url.append(queryItems: [
            URLQueryItem(name: "startDate", value: month + "-01"),
            URLQueryItem(name: "resampleFreq", value: "monthly"),
        ])
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PortfolioLabPriceServiceError.unavailable
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300: break
        case 401, 403: throw PortfolioLabPriceServiceError.unauthorized
        case 429: throw PortfolioLabPriceServiceError.rateLimited
        default:
            Self.logger.error("Tiingo request for \(symbol, privacy: .public) failed")
            throw PortfolioLabPriceServiceError.unavailable
        }
        return try Self.parse(data, symbol: symbol)
    }

    private struct Bar: Decodable {
        let date: String
        let adjClose: Double?
        let close: Double?
    }

    /// Month-end bars → closes keyed `YYYY-MM`, using dividend- and split-adjusted prices.
    static func parse(_ data: Data, symbol: String) throws -> [PortfolioLabClose] {
        guard let bars = try? JSONDecoder().decode([Bar].self, from: data) else {
            throw PortfolioLabPriceServiceError.invalidResponse(symbol)
        }
        return bars.compactMap { bar in
            guard bar.date.count >= 7, let value = bar.adjClose ?? bar.close else { return nil }
            return PortfolioLabClose(month: String(bar.date.prefix(7)), close: value)
        }
    }
}
