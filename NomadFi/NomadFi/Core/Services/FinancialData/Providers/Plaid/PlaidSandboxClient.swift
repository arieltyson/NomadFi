// PlaidSandboxClient.swift
// NomadFi
//
// Thin HTTP client that talks to the local Plaid sandbox broker under
// `tools/plaid-sandbox-broker/`. The broker is the only process in
// this stack that ever holds Plaid `client_id` / `secret`; this client
// only ever sees opaque item handles and `/transactions/sync` diffs.
//
// The client is a protocol + production HTTP implementation so tests
// substitute an in-memory stub without standing up a real broker.

import Foundation
import OSLog

// MARK: - Protocol

/// The narrow set of broker endpoints NomadFi's adapter exercises.
/// Intentionally smaller than the Plaid REST surface: Auth is only
/// available as a side effect of `/accounts/get`, `/sandbox/*` is
/// dev-only, and history / identity are out of scope for this proof.
protocol PlaidSandboxClient: Sendable {

    /// Calls the broker's `GET /health` endpoint and returns the
    /// response. Used by the developer-only diagnostics view.
    func health() async throws -> PlaidBrokerHealthResponse

    /// Asks the broker for a Plaid `link_token` the app can hand to
    /// Plaid's Link SDK. Not exercised end-to-end in this slice.
    func createLinkToken() async throws -> PlaidLinkTokenResponse

    /// Dev-only convenience the broker exposes by wrapping Plaid's
    /// `/sandbox/public_token/create` + `/item/public_token/exchange`.
    /// Returns an opaque item handle the app stores in the Keychain.
    /// Only used when no real Link flow is available.
    func createSandboxItem() async throws -> PlaidItemHandleResponse

    /// Exchanges a Plaid `public_token` captured from the real Link
    /// success callback for an opaque item handle. The broker
    /// performs the actual `/item/public_token/exchange` call; the
    /// app never sees the resulting `access_token`.
    func exchangePublicToken(_ publicToken: String) async throws -> PlaidItemHandleResponse

    /// Fetches the current account list + balances for an item. The
    /// broker also returns the institution name so the adapter can
    /// stamp it on the snapshot without a second hop.
    func fetchAccounts(itemID: String) async throws -> PlaidAccountsResponse

    /// Calls `/transactions/sync` via the broker. `cursor` may be nil
    /// on the first pull; the broker returns the full initial diff
    /// plus a new cursor NomadFi persists in the Keychain.
    func syncTransactions(
        itemID: String,
        cursor: String?
    ) async throws -> PlaidTransactionsSyncResponse
}

// MARK: - Production HTTP implementation

/// URLSession-backed production client. Never contacts plaid.com
/// directly — always routes through the local broker.
struct LivePlaidSandboxClient: PlaidSandboxClient {

    let baseURL: URL
    let session: URLSession
    let brokerSecret: String?
    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.PlaidSandbox"
    )

    init(
        baseURL: URL,
        session: URLSession = .shared,
        brokerSecret: String? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.brokerSecret = brokerSecret
    }

    func health() async throws -> PlaidBrokerHealthResponse {
        try await get(path: "/health")
    }

    func createLinkToken() async throws -> PlaidLinkTokenResponse {
        try await post(path: "/link/token/create", body: EmptyBody())
    }

    func createSandboxItem() async throws -> PlaidItemHandleResponse {
        try await post(path: "/sandbox/item/create", body: EmptyBody())
    }

    func exchangePublicToken(_ publicToken: String) async throws -> PlaidItemHandleResponse {
        try await post(
            path: "/item/public_token/exchange",
            body: PublicTokenBody(publicToken: publicToken)
        )
    }

    func fetchAccounts(itemID: String) async throws -> PlaidAccountsResponse {
        try await post(path: "/accounts/get", body: ItemIDBody(itemID: itemID))
    }

    func syncTransactions(
        itemID: String,
        cursor: String?
    ) async throws -> PlaidTransactionsSyncResponse {
        try await post(
            path: "/transactions/sync",
            body: SyncBody(itemID: itemID, cursor: cursor)
        )
    }

    // MARK: - Plumbing

    private func get<Response: Decodable>(path: String) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applySharedSecret(to: &request)
        return try await dispatch(request: request, path: path)
    }

    private func post<Request: Encodable, Response: Decodable>(
        path: String,
        body: Request
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        applySharedSecret(to: &request)
        return try await dispatch(request: request, path: path)
    }

    /// Sends the shared secret as an `X-NomadFi-Broker-Secret`
    /// header. Only set when the developer has configured a secret
    /// (i.e. broker is in LAN mode). Loopback-only brokers ignore
    /// the header if they see it.
    private func applySharedSecret(to request: inout URLRequest) {
        if let brokerSecret, !brokerSecret.isEmpty {
            request.setValue(brokerSecret, forHTTPHeaderField: "X-NomadFi-Broker-Secret")
        }
    }

    private func dispatch<Response: Decodable>(
        request: URLRequest,
        path: String
    ) async throws -> Response {

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Self.logger.error(
                "Plaid sandbox broker transport failed: \(error.localizedDescription, privacy: .public)"
            )
            throw FinancialDataProviderError.refreshFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FinancialDataProviderError.refreshFailed
        }

        if httpResponse.statusCode == 503 {
            throw FinancialDataProviderError.providerUnavailable(.integrationNotImplemented)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            Self.logger.error(
                "Plaid sandbox broker \(path, privacy: .public) status \(httpResponse.statusCode, privacy: .public)"
            )
            throw FinancialDataProviderError.refreshFailed
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            Self.logger.error(
                "Plaid sandbox decode failed for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw FinancialDataProviderError.mappingFailed(field: path)
        }
    }

    // MARK: - Request bodies

    private struct EmptyBody: Encodable {}

    private struct ItemIDBody: Encodable {
        let itemID: String
        enum CodingKeys: String, CodingKey { case itemID = "item_id" }
    }

    private struct SyncBody: Encodable {
        let itemID: String
        let cursor: String?
        enum CodingKeys: String, CodingKey {
            case itemID = "item_id"
            case cursor
        }
    }

    private struct PublicTokenBody: Encodable {
        let publicToken: String
        enum CodingKeys: String, CodingKey {
            case publicToken = "public_token"
        }
    }
}
