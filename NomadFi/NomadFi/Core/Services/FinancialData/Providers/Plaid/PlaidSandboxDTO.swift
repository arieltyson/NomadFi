// PlaidSandboxDTO.swift
// NomadFi
//
// Narrow Codable DTOs for the Plaid sandbox proof. These are the only
// Plaid-specific types the app imports; they live behind the
// external-aggregator adapter boundary so the core domain model and
// reconciler never see Plaid shapes.
//
// Shapes are derived only from Plaid's official documentation:
// - https://plaid.com/docs/api/products/transactions/
// - https://plaid.com/docs/transactions/sync/
// - https://plaid.com/docs/api/products/balance/
// - https://plaid.com/docs/api/products/auth/
// - https://plaid.com/docs/api/link/
//
// Fields NomadFi does not need right now are intentionally omitted
// rather than mapped. The proof only needs what the Decision Assistant
// can actually consume today.

import Foundation

// MARK: - Health (broker → app)

/// Minimal health response the broker returns from `GET /health`.
/// Covers only what NomadFi's developer diagnostics view reads. The
/// broker may add fields later; extra fields are ignored.
struct PlaidBrokerHealthResponse: Codable, Sendable, Equatable {

    /// `true` when the broker booted in `sandbox` env. Anything else
    /// is a configuration bug — loopback or LAN mode does not matter
    /// to the app here.
    let ok: Bool

    /// Which Plaid environment the broker is pointing at. Always
    /// `"sandbox"` by contract; surfaced so the diagnostics view can
    /// display it honestly.
    let env: String

    /// True when the broker requires an `X-NomadFi-Broker-Secret`
    /// header on every call (LAN mode). Optional for backwards
    /// compatibility with older loopback-only broker versions that
    /// never returned this field.
    let requiresSecret: Bool?

    /// True when the broker has been started with a configured
    /// `PLAID_REDIRECT_URI`. Used by the diagnostics view to
    /// surface OAuth readiness calmly.
    let redirectURIConfigured: Bool?

    enum CodingKeys: String, CodingKey {
        case ok
        case env
        case requiresSecret = "requires_secret"
        case redirectURIConfigured = "redirect_uri_configured"
    }
}

// MARK: - Link token (broker → app)

/// Envelope the local broker returns after calling Plaid's
/// `/link/token/create` endpoint on NomadFi's behalf. Only the
/// `link_token` crosses the broker → app boundary.
struct PlaidLinkTokenResponse: Codable, Sendable, Equatable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

// MARK: - Item exchange (broker → app)

/// After the broker has handled the public_token → access_token
/// exchange with Plaid, it returns an opaque item handle that NomadFi
/// persists in the Keychain. The real access_token stays on the broker.
struct PlaidItemHandleResponse: Codable, Sendable, Equatable {
    let itemID: String
    let institutionID: String?
    let institutionName: String?

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case institutionID = "institution_id"
        case institutionName = "institution_name"
    }
}

// MARK: - Accounts (Plaid `/accounts/get` shape via broker)

/// Plaid account-type enumeration. String-backed so unknown upstream
/// values decode cleanly to `.other`. Source:
/// https://plaid.com/docs/api/accounts/.
enum PlaidAccountType: String, Codable, Sendable {
    case depository
    case credit
    case loan
    case investment
    case brokerage
    case other
}

struct PlaidBalances: Codable, Sendable, Equatable {
    /// Deposit-style "current" balance on depository accounts; owed
    /// balance on credit accounts. Nullable per Plaid docs.
    let current: Double?

    /// Deposit-style available-after-holds balance on depository
    /// accounts; remaining credit on credit accounts.
    let available: Double?

    /// Credit limit on credit accounts; nil for deposit accounts.
    let limit: Double?

    let isoCurrencyCode: String?
    let unofficialCurrencyCode: String?

    enum CodingKeys: String, CodingKey {
        case current
        case available
        case limit
        case isoCurrencyCode = "iso_currency_code"
        case unofficialCurrencyCode = "unofficial_currency_code"
    }
}

struct PlaidAccount: Codable, Sendable, Equatable, Identifiable {
    /// Stable upstream account ID. Used as the durable link on
    /// NomadFi's `Account.providerExternalAccountID`.
    let accountID: String
    let name: String
    let officialName: String?
    let mask: String?
    let type: PlaidAccountType
    let subtype: String?
    let balances: PlaidBalances

    var id: String { accountID }

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case name
        case officialName = "official_name"
        case mask
        case type
        case subtype
        case balances
    }
}

/// Response wrapper the broker returns alongside the account list so
/// NomadFi can stamp the institution name without a second hop.
struct PlaidAccountsResponse: Codable, Sendable, Equatable {
    let accounts: [PlaidAccount]
    let institutionName: String?

    enum CodingKeys: String, CodingKey {
        case accounts
        case institutionName = "institution_name"
    }
}

// MARK: - Transactions (`/transactions/sync` shape)

struct PlaidTransaction: Codable, Sendable, Equatable, Identifiable {
    let transactionID: String
    let accountID: String
    let amount: Double
    let isoCurrencyCode: String?
    let unofficialCurrencyCode: String?
    let date: String
    let authorizedDate: String?
    let merchantName: String?
    let name: String
    let pending: Bool
    let personalFinanceCategory: PlaidPersonalFinanceCategory?
    let paymentChannel: String?

    var id: String { transactionID }

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case accountID = "account_id"
        case amount
        case isoCurrencyCode = "iso_currency_code"
        case unofficialCurrencyCode = "unofficial_currency_code"
        case date
        case authorizedDate = "authorized_date"
        case merchantName = "merchant_name"
        case name
        case pending
        case personalFinanceCategory = "personal_finance_category"
        case paymentChannel = "payment_channel"
    }
}

struct PlaidPersonalFinanceCategory: Codable, Sendable, Equatable {
    /// Top-level Plaid PFC primary category (e.g. `FOOD_AND_DRINK`).
    /// Enumerated and documented at
    /// https://plaid.com/docs/transactions/personal-finance-categories/.
    let primary: String
    let detailed: String?
    let confidenceLevel: String?

    enum CodingKeys: String, CodingKey {
        case primary
        case detailed
        case confidenceLevel = "confidence_level"
    }
}

/// `/transactions/sync` response as the broker proxies it back to the
/// app. NomadFi only consumes the diff payload + the new cursor.
struct PlaidTransactionsSyncResponse: Codable, Sendable, Equatable {
    let added: [PlaidTransaction]
    let modified: [PlaidTransaction]
    /// Plaid returns full objects in `removed` only on some endpoints;
    /// `/sync` returns just the IDs. Typed as a narrow shape.
    let removed: [PlaidRemovedTransaction]
    let nextCursor: String
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case added
        case modified
        case removed
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct PlaidRemovedTransaction: Codable, Sendable, Equatable {
    let transactionID: String

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
    }
}

// MARK: - Broker errors

/// Error envelope the broker returns when it cannot proxy a Plaid
/// call. Kept separate from `FinancialDataProviderError` because this
/// is a transport-layer shape; the adapter translates it.
struct PlaidBrokerErrorResponse: Codable, Sendable, Equatable {
    let errorCode: String?
    let errorType: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorType = "error_type"
        case errorMessage = "error_message"
    }
}
