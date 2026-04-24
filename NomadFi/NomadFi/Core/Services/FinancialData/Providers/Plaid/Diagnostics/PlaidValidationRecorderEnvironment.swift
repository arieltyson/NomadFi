// PlaidValidationRecorderEnvironment.swift
// NomadFi
//
// SwiftUI environment key for the DEBUG-only Plaid validation
// recorder. The app root instantiates one and injects it so the
// developer harness, the Financial Connections page, and the Plaid
// Link coordinator all write into the same session instance — the
// developer can start a session in the harness, navigate to the
// connections page, run Plaid Link, navigate back, and export from
// the harness without losing events to a fresh recorder.
//
// Defaults follow the same pattern as `plaidLinkCoordinator`:
// environment resolution happens on the main actor, so the default
// value is built via `MainActor.assumeIsolated` inside a nonisolated
// getter.

#if DEBUG

import SwiftUI

private struct PlaidValidationRecorderKey: EnvironmentKey {
    static var defaultValue: PlaidValidationRecorder {
        MainActor.assumeIsolated { SharedDefault.instance }
    }
}

@MainActor
private enum SharedDefault {
    static let instance = PlaidValidationRecorder()
}

extension EnvironmentValues {
    var plaidValidationRecorder: PlaidValidationRecorder {
        get { self[PlaidValidationRecorderKey.self] }
        set { self[PlaidValidationRecorderKey.self] = newValue }
    }
}

#endif
