// FinancialDataProvider.swift
// NomadFi
//
// Unified contract for every upstream financial data source the app
// talks to. Replaces the earlier single-provider ``FinanceDataService``
// abstraction so NomadFi isn't hard-wired to FinanceKit or any one
// aggregator.
//
// Design rules:
// - The core domain model (``Account`` / ``Transaction``) is the source
//   of truth. Providers return *snapshots* that the coordinator
//   reconciles into the store; they never replace the model.
// - Availability and authorization are separate concerns. A provider
//   can be "available on this device" but still need a consent prompt.
// - Graceful degradation is mandatory. If this provider cannot run,
//   the coordinator falls back to the manual / CSV / next-best source.
// - No vendor SDK leaks into this file. FinanceKit-specific imports
//   live inside `FinanceKitFinancialDataProvider`; Plaid/MX/Akoya/
//   Finicity would land inside the external-aggregator seam.

import Foundation

/// A single source of financial data NomadFi can query. Every
/// concrete provider (manual, CSV, FinanceKit, external aggregator)
/// conforms to this protocol.
///
/// Providers are ``Sendable`` so the ``FinancialDataSyncCoordinator``
/// can fan them out concurrently. Implementations must not hold
/// main-actor state; UI bridging happens in the coordinator.
protocol FinancialDataProvider: Sendable {

    /// Stable identity for this provider. The coordinator keys its
    /// fallback logic on this.
    var kind: FinancialDataProviderKind { get }

    /// Whether the provider can run on this device right now. Cheap
    /// to call; must not prompt the user. The coordinator consults
    /// availability before authorization so UI can avoid prompting
    /// for consent NomadFi cannot honour.
    func availability() async -> FinancialDataProviderAvailability

    /// Current authorization state. Must not prompt.
    func authorizationStatus() async -> FinancialDataAuthorizationStatus

    /// Ask the provider to prompt the user for consent. Only called
    /// in response to an explicit user action. Throws when the
    /// provider is unavailable; returns the updated status on
    /// success or declined consent.
    func requestAuthorization() async throws -> FinancialDataAuthorizationStatus

    /// Open connections this provider currently manages. For the
    /// manual / CSV providers this is always a single implicit
    /// connection; for FinanceKit and aggregators it reflects the
    /// real upstream link state. May be empty when the provider is
    /// available but has not been set up yet.
    func connections() async -> [FinancialDataConnection]

    /// Fetch the latest account snapshots the provider can produce.
    /// Providers that do not expose account discovery (manual, CSV
    /// today) return an empty array; providers that can but have
    /// nothing connected also return empty — neither path should
    /// throw.
    func fetchAccountSnapshots() async throws -> [FinancialAccountSnapshot]

    /// Fetch transaction snapshots for one of this provider's
    /// accounts, bounded by date. The coordinator applies dedupe and
    /// merge policy; the provider is responsible for returning the
    /// narrowest possible result.
    func fetchTransactionSnapshots(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [FinancialTransactionSnapshot]
}
