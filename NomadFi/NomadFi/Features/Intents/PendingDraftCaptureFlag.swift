// PendingDraftCaptureFlag.swift
// NomadFi
//
// One-shot routing flag that asks the in-app Decision Assistant
// to present the typed `DecisionDraftFormView`. The typed-form
// launch path has no payload to carry (the form starts blank),
// so a `Bool` sentinel is enough — no need for a value type
// like `PendingAIIntakeRequest`. Stored in the App Group shared
// suite so the widget extension's process and the main app's
// process see the same flag.
//
// Shape mirrors `PendingAIIntakeRequestStore` (read / write /
// clear / consume) so all routing slots in the app share one
// vocabulary; the differing payload (Bool sentinel vs. typed
// payload) is the only thing that varies.
//
// Honesty contract pinned in `PendingDraftCaptureFlagTests`:
//
//   • `consume(from:)` is one-shot — calling it twice returns
//     `true` once and `false` thereafter.
//   • `clear(in:)` always leaves the slot empty regardless of
//     prior state; safe to call defensively.
//   • Defaults route through `AppRoutingDefaults.shared` so
//     cross-process writes (widget tap) are observable from the
//     main-app consumer.

import Foundation
import OSLog

/// Pure namespace adapter for the typed-form launch flag.
enum PendingDraftCaptureFlag {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "PendingDraftCaptureFlag"
    )

    /// `@AppStorage` storage key for the flag. Namespaced under
    /// `nomadfi.draftCapture` so it sits next to the AI-intake
    /// slot (`nomadfi.aiIntake.pendingRequest`) and the tab
    /// selection slot (`nomadfi.mainTab.selection`) under one
    /// greppable umbrella.
    static let storageKey: String = "nomadfi.draftCapture.pendingRequest"

    // MARK: - Read

    /// Reads the current flag value. Pure — does not mutate the
    /// slot. Callers that want one-shot semantics use
    /// `consume(from:)`.
    static func read(
        from defaults: UserDefaults = AppRoutingDefaults.shared
    ) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    /// One-shot read — returns the flag and atomically clears it
    /// so the consumer cannot accidentally honour the same launch
    /// twice.
    static func consume(
        from defaults: UserDefaults = AppRoutingDefaults.shared
    ) -> Bool {
        let value = read(from: defaults)
        clear(in: defaults)
        return value
    }

    // MARK: - Write / clear

    /// Sets the flag to `true`. Subsequent `read` / `consume`
    /// calls will see `true` until either `consume` runs or
    /// `clear` is called.
    static func write(
        to defaults: UserDefaults = AppRoutingDefaults.shared
    ) {
        defaults.set(true, forKey: storageKey)
    }

    /// Idempotent clear — leaves the slot empty regardless of
    /// prior contents. Safe to call defensively.
    static func clear(
        in defaults: UserDefaults = AppRoutingDefaults.shared
    ) {
        defaults.removeObject(forKey: storageKey)
    }
}
