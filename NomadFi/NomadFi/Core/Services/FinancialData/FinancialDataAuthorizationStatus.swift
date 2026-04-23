// FinancialDataAuthorizationStatus.swift
// NomadFi
//
// Provider-neutral authorization state. Mirrors the shape of Apple's
// `FinanceKit.AuthorizationStatus` but is intentionally broader so
// future providers (CSV, external aggregator) can describe their own
// consent posture without leaking framework-specific types into the
// core domain model.

import Foundation

/// Whether NomadFi currently has permission to read data from a given
/// ``FinancialDataProvider``. The coordinator exposes this per-kind so
/// UI can degrade gracefully instead of pretending unsupported data
/// exists.
enum FinancialDataAuthorizationStatus: Sendable, Equatable {

    /// The provider has granted read access. Data may still be
    /// unavailable for other reasons (offline, stale), but consent
    /// is not the blocker.
    case authorized

    /// The user explicitly declined, or a managed policy revoked
    /// access. NomadFi must not retry silently.
    case denied

    /// The user has not been prompted yet. The coordinator may call
    /// ``FinancialDataProvider/requestAuthorization()`` in response
    /// to an explicit user action.
    case notDetermined

    /// Consent is not the gating factor — the provider itself is not
    /// available on this device or in this region (e.g. FinanceKit
    /// without the managed entitlement, or no supported institution).
    /// Treated as "graceful degradation" by the coordinator.
    case unavailable
}
