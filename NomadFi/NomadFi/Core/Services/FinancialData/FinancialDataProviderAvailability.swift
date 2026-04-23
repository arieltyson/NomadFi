// FinancialDataProviderAvailability.swift
// NomadFi
//
// Typed description of whether a provider can be used right now.
// Separate from ``FinancialDataAuthorizationStatus`` because a
// provider can be available on this device but still waiting on
// user consent (e.g. FinanceKit entitlement granted, user has not
// yet tapped "Allow"). Likewise a provider can be entirely
// unavailable regardless of consent (no entitlement, no region
// coverage, no aggregator integration yet).

import Foundation

/// Whether a ``FinancialDataProvider`` is usable on this device at all.
/// UI should consult this before prompting the user for consent so the
/// app never claims coverage it does not have.
enum FinancialDataProviderAvailability: Sendable, Equatable {

    /// The provider is fully installed and callable. Authorization is
    /// a separate check.
    case available

    /// The provider is installed but not yet set up (e.g. no CSV has
    /// been imported yet, or no external-aggregator link exists).
    /// Equivalent to "available, but there's nothing to sync".
    case availableNoConnections

    /// The provider exists conceptually (FinanceKit, an aggregator)
    /// but cannot run here. NomadFi surfaces a calm explanation
    /// rather than a retry loop. `reason` is log-safe, never the
    /// place to put user-facing copy.
    case unavailable(reason: UnavailableReason)

    /// Reason a provider is not usable right now. Kept narrow on
    /// purpose: UI maps each case to honest copy; the app never
    /// invents coverage claims.
    enum UnavailableReason: Sendable, Equatable {

        /// The host platform does not expose the underlying API
        /// (e.g. FinanceKit is Apple-only; NomadFi only runs on
        /// Apple platforms today but the case stays for clarity).
        case notSupportedOnPlatform

        /// The framework is present but the data class is not
        /// available here (e.g. `FinanceStore.isDataAvailable`
        /// returns false). Region / device / OS restrictions apply.
        case notSupportedOnDevice

        /// Apple's managed entitlement has not been granted. The
        /// adapter seam is in place; nothing ships until Apple
        /// provisions the entitlement.
        case entitlementNotProvisioned

        /// The adapter itself is a placeholder. Used by the
        /// external-aggregator seam so a future integration has a
        /// clear landing spot without shipping a half-built SDK.
        case integrationNotImplemented

        /// Structured log label. Never render this directly in UI.
        var logLabel: String {
            switch self {
            case .notSupportedOnPlatform: "not_supported_on_platform"
            case .notSupportedOnDevice: "not_supported_on_device"
            case .entitlementNotProvisioned: "entitlement_not_provisioned"
            case .integrationNotImplemented: "integration_not_implemented"
            }
        }
    }

    /// Convenience: true when the provider itself can run, regardless
    /// of whether any connection is set up yet.
    var isAvailable: Bool {
        switch self {
        case .available, .availableNoConnections: true
        case .unavailable: false
        }
    }
}
