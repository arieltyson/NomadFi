// ExternalAggregatorFinancialDataProvider.swift
// NomadFi
//
// Placeholder adapter for a future permissioned third-party
// aggregator (Plaid / MX / Akoya / Finicity, or an FDX/FAPI-shaped
// direct bank API). NomadFi does not ship any such SDK today — this
// file exists specifically to pin the adapter boundary so a later
// provider can be plugged in without restructuring the coordinator
// or core engines.
//
// Design rules for whoever lands the real integration later:
// - Do not import a vendor SDK into the core domain model. Keep the
//   import confined to this file (and any helper files alongside it).
// - Map the vendor's account / transaction / balance shapes into
//   ``FinancialAccountSnapshot`` and ``FinancialTransactionSnapshot``
//   inside this adapter. The rest of the app keeps consuming the
//   provider-neutral snapshots.
// - Represent connected-institution identity, transaction history,
//   balance refresh, coverage, and consent state as properties on
//   ``FinancialDataConnection`` — not as vendor-specific extensions.
// - Honour CFPB 1033-style principles: explicit authorization,
//   minimum necessary data, disclosed aggregator use, retention
//   policy. None of those belong in this stub; they belong in the
//   adapter once it exists.
//
// Until then, this placeholder reports ``UnavailableReason/integrationNotImplemented``
// so the coordinator can exercise its degradation logic end-to-end
// without ambiguity.

import Foundation

/// Placeholder provider for a future permissioned aggregator.
/// Always reports itself as unavailable; returns an empty set of
/// connections and snapshots. Constructed with an opaque identifier
/// so a later Plaid-vs-Akoya bakeoff can differentiate candidates
/// without leaking either vendor's types into the core domain model.
struct ExternalAggregatorFinancialDataProvider: FinancialDataProvider {

    let kind: FinancialDataProviderKind

    /// - Parameter identifier: Short, opaque tag for this candidate.
    ///   Kept out of the core domain model; only the adapter and the
    ///   coordinator's log output consume it.
    init(identifier: String = "") {
        self.kind = .externalAggregator(identifier: identifier)
    }

    func availability() async -> FinancialDataProviderAvailability {
        .unavailable(reason: .integrationNotImplemented)
    }

    func authorizationStatus() async -> FinancialDataAuthorizationStatus {
        .unavailable
    }

    func requestAuthorization() async throws -> FinancialDataAuthorizationStatus {
        throw FinancialDataProviderError.providerUnavailable(.integrationNotImplemented)
    }

    func connections() async -> [FinancialDataConnection] {
        []
    }

    func fetchAccountSnapshots() async throws -> [FinancialAccountSnapshot] {
        throw FinancialDataProviderError.providerUnavailable(.integrationNotImplemented)
    }

    func fetchTransactionSnapshots(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [FinancialTransactionSnapshot] {
        throw FinancialDataProviderError.providerUnavailable(.integrationNotImplemented)
    }
}
