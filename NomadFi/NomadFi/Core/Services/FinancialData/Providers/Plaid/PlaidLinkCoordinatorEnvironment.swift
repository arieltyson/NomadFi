// PlaidLinkCoordinatorEnvironment.swift
// NomadFi
//
// SwiftUI `Environment` key for the Plaid Link coordinator. The
// coordinator is a reference-typed `@Observable` state machine that
// the app root owns and that the Settings → Financial Connections
// page observes. Routing it through the environment lets the root's
// `.onOpenURL` forward universal-link returns to the same instance
// the Settings page is driving.
//
// The `EnvironmentKey.defaultValue` requirement is nonisolated, so we
// resolve the fallback lazily through `MainActor.assumeIsolated`. The
// default value is only ever read inside the SwiftUI view graph —
// which already runs on the main actor — so the assumption holds.
// This keeps the key usable in Swift 6 strict-concurrency builds.

import SwiftUI

private struct PlaidLinkCoordinatorKey: EnvironmentKey {
    static var defaultValue: PlaidLinkCoordinator {
        MainActor.assumeIsolated { SharedDefault.instance }
    }
}

/// Shared singleton used only when nothing has injected a coordinator
/// into the environment (e.g. SwiftUI previews without an owning
/// root). Production code always overrides the key with the
/// `@State` instance owned by `NomadFiApp`.
@MainActor
private enum SharedDefault {
    static let instance = PlaidLinkCoordinator()
}

extension EnvironmentValues {
    var plaidLinkCoordinator: PlaidLinkCoordinator {
        get { self[PlaidLinkCoordinatorKey.self] }
        set { self[PlaidLinkCoordinatorKey.self] = newValue }
    }
}
