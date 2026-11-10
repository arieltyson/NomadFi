// PendingAIIntakeRequest.swift
// NomadFi
//
// Value-typed payload that an App Intent (running in
// `.foreground(.immediate)` mode) hands to the in-app Decision
// Assistant so the existing `DecisionAIIntakeSheet` can be opened.
// Carries either a pre-seeded scenario string (Siri / Shortcut
// dictation) or `nil` for a blank launch (one-tap Control Widget).
//
// Why a value type with a string round-trip:
//   `@AppStorage` only natively persists a small set of primitive
//   types — `String` is the cleanest universal target. Encoding
//   the payload as a JSON string lets us add fields later (e.g.
//   suggested kind, suggested currency) without touching every
//   call site, while still making the contract type-safe at the
//   value-layer boundary.
//
// Why one slot for two launch shapes:
//   The Decision Assistant already consumes this single slot via
//   `@AppStorage` on `PendingAIIntakeRequest.storageKey`. Reusing
//   the same slot for the blank-launch path keeps the routing
//   surface narrow — the consumer's behaviour is identical
//   ("open the AI intake sheet"), only the seed text differs.
//   Using one slot means the sheet's appearance is reactive to
//   *any* upstream entry point through one observation point.
//
// Why no SwiftData model:
//   Per the Phase 9A system-surface follow-through brief, the
//   pending-request handoff must not introduce a new persistence
//   model. `UserDefaults` (via `@AppStorage` on the consumer side)
//   matches the existing `MainTabSelection` routing pattern, costs
//   nothing to clear, and never bleeds into CloudKit sync.

import Foundation

/// One-shot routing payload that asks the app to open the on-device
/// AI intake flow. Read once by `DecisionAssistantView` and then
/// cleared from `UserDefaults` so the sheet does not keep
/// reappearing on every render.
struct PendingAIIntakeRequest: Sendable, Equatable, Hashable {

    /// The natural-language scenario the user dictated to Siri /
    /// supplied to the Shortcut. Trimmed by the producer; the
    /// consumer trusts this value as-is.
    ///
    /// `nil` means "blank launch" — the user tapped a one-tap
    /// surface (Control Widget / Lock Screen / Action button)
    /// that has no scenario string to seed. The consumer opens the
    /// AI intake sheet with an empty scenario field.
    let scenarioText: String?

    /// Convenience constructor for blank-launch requests
    /// originating from a `ControlWidgetButton` tap. Equivalent to
    /// `init(scenarioText: nil)` but reads more clearly at the
    /// call site than passing `nil`.
    static let blankLaunch = PendingAIIntakeRequest(scenarioText: nil)
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
    ///
    /// Custom encode/decode tightens the JSON shape:
    ///
    ///   • Encode always emits the `scenarioText` key, even when
    ///     nil — blank-launch payloads serialise as
    ///     `{"scenarioText":null}` rather than the default `{}`
    ///     Swift produces for an Optional with a `nil` value. This
    ///     matches the literal the widget extension's mirror
    ///     `StartAIIntakeIntent` writes (the widget cannot import
    ///     this value type) and pins the contract via
    ///     `PendingAIIntakeRequestTests.widgetCopyMatchesBlankLaunchEncoding`.
    ///   • Decode requires the `scenarioText` key to be *present*
    ///     (either as `null` or as a string). A JSON object that
    ///     simply lacks the key (`{"unrelated":"shape"}`) is
    ///     treated as malformed and rejected via
    ///     `init?(rawValue:)` returning `nil` — defensive against
    ///     a corrupted UserDefaults slot or a future schema
    ///     drift.
    private struct Storage: Codable {

        let scenarioText: String?

        private enum CodingKeys: String, CodingKey {
            case scenarioText
        }

        init(scenarioText: String?) {
            self.scenarioText = scenarioText
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard container.contains(.scenarioText) else {
                throw DecodingError.keyNotFound(
                    CodingKeys.scenarioText,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "PendingAIIntakeRequest payload requires the `scenarioText` key (either a string or null)."
                    )
                )
            }
            self.scenarioText = try container.decodeIfPresent(
                String.self,
                forKey: .scenarioText
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Use the unconditional `encode(_:forKey:)` so the key
            // is always written, even when `scenarioText` is nil
            // — Swift's default Optional encoding would omit the
            // key entirely, breaking the widget mirror's literal.
            try container.encode(scenarioText, forKey: .scenarioText)
        }
    }
}
