// PendingAIIntakeRequestStore.swift
// NomadFi
//
// Pure namespace adapter that reads and writes
// `PendingAIIntakeRequest` payloads to a `UserDefaults` slot. Lives
// in its own file so:
//
//   • App Intents (`OpenAIIntakeIntent`) write through this type
//     instead of touching `UserDefaults` directly — no stringly-
//     typed key drift.
//   • The consumer (`DecisionAssistantView`) can use the
//     `consume(from:)` one-shot helper from a `Task @MainActor`
//     context for paths that don't fit the `@AppStorage` reactive
//     model, while still using `@AppStorage` as the read-trigger.
//   • Tests can pass a fresh `UserDefaults(suiteName:)` so they
//     never pollute the production routing slot.
//
// Defaults to the App Group shared suite via
// `AppRoutingDefaults.shared` so cross-process writes (widget
// extension's `ControlWidgetButton` tap) are observable from the
// main-app consumer. Routing through `UserDefaults.standard`
// would re-create the original bug — the widget process and
// main-app process see different `.standard` stores, so the
// hand-off would silently no-op on the control surface.
//
// Honesty contract pinned in
// `PendingAIIntakeRequestStoreTests`:
//
//   • `consume(from:)` is one-shot — calling it twice in a row
//     returns the request once and `nil` thereafter, even if the
//     producer never wrote a fresh payload.
//   • `clear(in:)` always leaves the slot empty regardless of the
//     prior state; safe to call defensively.
//   • Round-trip is total — anything `write(_:to:)` puts in,
//     `read(from:)` reads back as the same value.

import Foundation
import OSLog

/// Pure adapter between `PendingAIIntakeRequest` and the
/// `UserDefaults` slot the App Intent layer hands across to the
/// SwiftUI Decisions surface.
enum PendingAIIntakeRequestStore {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "PendingAIIntakeRequestStore"
    )

    // MARK: - Read

    /// Decodes the request currently sitting in the slot, or `nil`
    /// when nothing is pending. Pure read — does not mutate the
    /// slot. Callers that want one-shot semantics use
    /// `consume(from:)`.
    static func read(
        from defaults: UserDefaults = AppRoutingDefaults.shared
    ) -> PendingAIIntakeRequest? {
        guard let raw = defaults.string(forKey: PendingAIIntakeRequest.storageKey),
              !raw.isEmpty
        else { return nil }
        return PendingAIIntakeRequest(rawValue: raw)
    }

    /// One-shot read — decodes the pending request and atomically
    /// clears the slot so the consumer cannot accidentally honour
    /// the same request twice. Safe to call from any thread that
    /// owns the supplied `UserDefaults`.
    static func consume(
        from defaults: UserDefaults = AppRoutingDefaults.shared
    ) -> PendingAIIntakeRequest? {
        let request = read(from: defaults)
        clear(in: defaults)
        return request
    }

    // MARK: - Write / clear

    /// Writes (or overwrites) the pending request. Subsequent
    /// `read` / `consume` calls will see this value until either
    /// `consume` runs or `clear` is called.
    static func write(
        _ request: PendingAIIntakeRequest,
        to defaults: UserDefaults = AppRoutingDefaults.shared
    ) {
        let raw = request.rawValue
        guard !raw.isEmpty else {
            logger.error(
                "Refused to write empty-encoded PendingAIIntakeRequest — would silently no-op the consumer."
            )
            return
        }
        defaults.set(raw, forKey: PendingAIIntakeRequest.storageKey)
    }

    /// Idempotent clear — leaves the slot empty regardless of the
    /// prior contents. Safe to call defensively.
    static func clear(
        in defaults: UserDefaults = AppRoutingDefaults.shared
    ) {
        defaults.removeObject(forKey: PendingAIIntakeRequest.storageKey)
    }
}
