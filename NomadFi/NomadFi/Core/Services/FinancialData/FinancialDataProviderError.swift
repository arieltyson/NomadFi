// FinancialDataProviderError.swift
// NomadFi
//
// Shared error type for the provider layer. Each case is log-safe and
// intentionally narrow — user-facing copy belongs in UI code, not on
// the error itself, so localisation can stay consistent across
// providers.

import Foundation

/// Error types surfaced by a ``FinancialDataProvider``. Providers
/// translate framework-specific failures into this shared surface so
/// the coordinator can apply the same fallback logic regardless of
/// which upstream raised.
enum FinancialDataProviderError: Error, Equatable, Sendable {

    /// Provider is not usable on this device / region / entitlement
    /// state. The coordinator should degrade to other providers.
    case providerUnavailable(FinancialDataProviderAvailability.UnavailableReason)

    /// User declined consent. NomadFi must not retry silently — the
    /// next attempt requires a user action.
    case authorizationDenied

    /// The provider could not complete the request this time
    /// (network, upstream outage). The coordinator may retry on the
    /// next user-initiated sync.
    case refreshFailed

    /// The provider returned data that could not be mapped into the
    /// provider-neutral snapshot contract. Surfaces as a degradation
    /// rather than a hard failure so partial results still ship.
    case mappingFailed(field: String)
}

extension FinancialDataProviderError: LocalizedError {

    /// Short, honest English summary. UI should prefer its own
    /// localised strings; this exists so log output stays readable.
    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let reason):
            "Provider unavailable: \(reason.logLabel)"
        case .authorizationDenied:
            "Provider authorization declined"
        case .refreshFailed:
            "Provider refresh failed"
        case .mappingFailed(let field):
            "Provider returned a value NomadFi could not map: \(field)"
        }
    }
}
