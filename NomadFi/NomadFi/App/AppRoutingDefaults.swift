// AppRoutingDefaults.swift
// NomadFi
//
// Single accessor for the App Group `UserDefaults` suite the
// app and its extensions share for cross-process routing
// payloads — `MainTabSelection.storageKey` and
// `PendingAIIntakeRequest.storageKey`. Lives next to
// `MainTabSelection.swift` so every routing concern in the
// main app reaches for one chokepoint.
//
// Why a dedicated helper:
//
//   The pre-existing routing implementation wrote routing
//   payloads through `UserDefaults.standard`, which is the
//   *current process's* defaults — different in the main app
//   and in the widget extension. A `ControlWidgetButton` tap
//   that runs the intent's `perform()` body in the widget
//   process therefore wrote to the widget's own defaults; the
//   main-app `@AppStorage` consumer never observed the write.
//   The cross-process routing was correct only by accident in
//   the foreground-immediate happy path.
//
//   The fix is to route every payload through the App Group
//   shared suite so the write is observable from either
//   process. The same suite already powers
//   `DashboardWidgetSnapshotStore` and its widget mirror, so
//   no new infrastructure is being added — we are extending
//   an established channel.
//
// Why hard-fail when the suite is unavailable:
//
//   The App Groups capability is build-time configuration; if
//   it is missing or misconfigured, the app's cross-process
//   routing is fundamentally broken and silent fallback to
//   `UserDefaults.standard` would re-create the original bug
//   the slice exists to fix. `preconditionFailure` makes the
//   misconfig immediately visible during development and in
//   TestFlight, before it reaches production users. Apple's
//   own guidance for entitlement-required infrastructure
//   leans the same way.

import Foundation
import OSLog

/// Pure namespace exposing the App Group shared
/// `UserDefaults` suite the app and its extensions use for
/// cross-process routing payloads. Reuses
/// `NomadFiWidgetSharedConstants.appGroupIdentifier` so the
/// snapshot channel and the routing channel share one
/// identifier.
enum AppRoutingDefaults {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "AppRoutingDefaults"
    )

    /// The App Group identifier — sourced from the existing
    /// snapshot constants so a future identifier rename touches
    /// one place rather than two.
    static var appGroupIdentifier: String {
        NomadFiWidgetSharedConstants.appGroupIdentifier
    }

    /// The shared `UserDefaults` suite. Lazily initialised on
    /// first access; `preconditionFailure` if the App Groups
    /// capability is unavailable so a broken build cannot
    /// silently fall back to per-process routing.
    ///
    /// `nonisolated(unsafe)` because `UserDefaults` is documented
    /// as thread-safe (its API is process-wide and uses internal
    /// synchronisation) but does not yet conform to `Sendable`.
    /// The Swift 6 annotation is the canonical way to opt out of
    /// the strict-concurrency check for a type the framework
    /// guarantees is safe to share across actors.
    nonisolated(unsafe) static let shared: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.fault(
                "App Group suite '\(appGroupIdentifier, privacy: .public)' is unavailable. The App Groups capability must be enabled on both the NomadFi target and the NomadFiWidgetExtension target with this identifier."
            )
            preconditionFailure(
                "App Group '\(appGroupIdentifier)' is unavailable. Verify the App Groups capability is enabled on both the NomadFi target and the NomadFiWidgetExtension target with the matching identifier."
            )
        }
        return defaults
    }()
}
