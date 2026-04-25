// PendingAIIntakeRequest.swift
// NomadFi
//
// Value-typed payload that an App Intent (running in
// `.foreground(.immediate)` mode) hands to the in-app Decision
// Assistant so the existing `DecisionAIIntakeSheet` can be opened
// with a scenario string already filled in.
//
// Why a value type with a string round-trip:
//   `@AppStorage` only natively persists a small set of primitive
//   types — `String` is the cleanest universal target. Encoding
//   the payload as a JSON string lets us add fields later (e.g.
//   suggested kind, suggested currency) without touching every
//   call site, while still making the contract type-safe at the
//   value-layer boundary.
//
// Why no SwiftData model:
//   Per the Phase 9A system-surface follow-through brief, the
//   pending-request handoff must not introduce a new persistence
//   model. `UserDefaults` (via `@AppStorage` on the consumer side)
//   matches the existing `MainTabSelection` routing pattern, costs
//   nothing to clear, and never bleeds into CloudKit sync.

import Foundation

/// One-shot routing payload that asks the app to open the on-device
/// AI intake flow with a pre-seeded scenario string. Read once by
/// `DecisionAssistantView` and then cleared from `UserDefaults` so
/// the sheet does not keep reappearing on every render.
struct PendingAIIntakeRequest: Sendable, Equatable, Hashable {

    /// The natural-language scenario the user dictated to Siri /
    /// supplied to the Shortcut. Trimmed by the producer; the
    /// consumer trusts this value as-is.
    let scenarioText: String
}

// MARK: - String round-trip for @AppStorage

extension PendingAIIntakeRequest {

    /// `@AppStorage` storage key for the encoded payload. Mirrors
    /// the `MainTabSelection.storageKey` pattern so all routing
    /// hand-offs sit under a single, greppable namespace.
    static let storageKey: String = "nomadfi.aiIntake.pendingRequest"

    /// JSON-decoded init for a string previously produced by
    /// `rawValue`. Returns `nil` for empty strings or malformed
    /// payloads — defensive so a corrupted slot can never crash the
    /// consumer.
    init?(rawValue: String) {
        guard !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Storage.self, from: data)
        else { return nil }
        self.scenarioText = decoded.scenarioText
    }

    /// JSON-encoded string suitable for `@AppStorage` storage.
    /// Always non-empty for a valid request — empty fallback is
    /// reserved for "nothing pending".
    var rawValue: String {
        let storage = Storage(scenarioText: scenarioText)
        guard let data = try? JSONEncoder().encode(storage),
              let string = String(data: data, encoding: .utf8)
        else { return "" }
        return string
    }

    /// Internal Codable shape. Kept private so callers cannot
    /// accidentally rely on the on-disk JSON layout — the
    /// `init?(rawValue:)` / `rawValue` boundary is the contract.
    private struct Storage: Codable {
        let scenarioText: String
    }
}
