// PendingAIIntakeRequestTests.swift
// NomadFi
//
// Pins the contract of the system-surface → in-app AI intake
// hand-off:
//
//   • `PendingAIIntakeRequest` round-trips losslessly through
//     `rawValue` / `init?(rawValue:)` so the `@AppStorage`-backed
//     hop between an App Intent and `DecisionAssistantView`
//     never silently drops the scenario string.
//   • Empty / malformed raw strings decode to `nil` rather than
//     crashing — defensive, since the slot is plain `UserDefaults`.
//   • `PendingAIIntakeRequestStore.consume(from:)` is *one-shot*:
//     a second call returns `nil` and the slot is empty afterward.
//   • `write` followed by `read` returns the same value;
//     `clear` empties the slot regardless of prior contents.
//
// All tests use a fresh `UserDefaults(suiteName:)` so they never
// pollute the developer's standard defaults.

import Foundation
import Testing

@testable import NomadFi

struct PendingAIIntakeRequestTests {

    // MARK: - Helpers

    /// Builds a fresh, isolated `UserDefaults` instance with a
    /// suite name unique per test invocation so concurrent test
    /// runs cannot cross-contaminate.
    private func makeDefaults(file: String = #fileID, line: Int = #line) -> UserDefaults {
        let suiteName = "nomadfi.tests.PendingAIIntakeRequest.\(file).\(line).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        guard let defaults else {
            fatalError("Could not allocate UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Value-type round-trip

    @Test("rawValue / init?(rawValue:) round-trip preserves the scenario text exactly")
    func roundTripPreservesScenario() throws {
        let original = PendingAIIntakeRequest(
            scenarioText: "Trying to figure out which card to use for the 2026 summer Amazon order."
        )
        let raw = original.rawValue
        #expect(!raw.isEmpty)

        let decoded = try #require(PendingAIIntakeRequest(rawValue: raw))
        #expect(decoded == original)
        #expect(decoded.scenarioText == original.scenarioText)
    }

    @Test("Empty raw string decodes to nil — defensive against an empty UserDefaults slot")
    func emptyRawDecodesToNil() {
        #expect(PendingAIIntakeRequest(rawValue: "") == nil)
    }

    @Test("Malformed raw string decodes to nil — never crashes on corrupted UserDefaults")
    func malformedRawDecodesToNil() {
        #expect(PendingAIIntakeRequest(rawValue: "not json at all") == nil)
        #expect(PendingAIIntakeRequest(rawValue: "{\"unrelated\":\"shape\"}") == nil)
    }

    @Test("Round-trip survives a scenario containing newlines, quotes, and emoji")
    func roundTripHandlesSpecialCharacters() throws {
        let scenario = "Line one\nLine \"two\" with quotes\nEmoji ✈️🌍 ok"
        let original = PendingAIIntakeRequest(scenarioText: scenario)
        let decoded = try #require(PendingAIIntakeRequest(rawValue: original.rawValue))
        #expect(decoded.scenarioText == scenario)
    }

    // MARK: - Store: read / write / clear

    @Test("write then read returns the same request — basic store contract")
    func writeThenReadReturnsSameRequest() {
        let defaults = makeDefaults()
        let request = PendingAIIntakeRequest(scenarioText: "A short scenario.")
        PendingAIIntakeRequestStore.write(request, to: defaults)

        let readBack = PendingAIIntakeRequestStore.read(from: defaults)
        #expect(readBack == request)
    }

    @Test("read does not mutate the slot — repeated reads return the same request")
    func readIsIdempotent() {
        let defaults = makeDefaults()
        let request = PendingAIIntakeRequest(scenarioText: "Idempotent read.")
        PendingAIIntakeRequestStore.write(request, to: defaults)

        let first = PendingAIIntakeRequestStore.read(from: defaults)
        let second = PendingAIIntakeRequestStore.read(from: defaults)
        #expect(first == request)
        #expect(second == request)
    }

    @Test("clear leaves the slot empty regardless of prior contents")
    func clearIsTotal() {
        let defaults = makeDefaults()
        PendingAIIntakeRequestStore.write(
            PendingAIIntakeRequest(scenarioText: "Will be cleared."),
            to: defaults
        )
        PendingAIIntakeRequestStore.clear(in: defaults)
        #expect(PendingAIIntakeRequestStore.read(from: defaults) == nil)

        // Calling clear on an empty slot is also a no-op — never throws.
        PendingAIIntakeRequestStore.clear(in: defaults)
        #expect(PendingAIIntakeRequestStore.read(from: defaults) == nil)
    }

    @Test("Empty slot reads as nil — defensive baseline")
    func emptySlotReadsAsNil() {
        let defaults = makeDefaults()
        #expect(PendingAIIntakeRequestStore.read(from: defaults) == nil)
        #expect(PendingAIIntakeRequestStore.consume(from: defaults) == nil)
    }

    // MARK: - Store: one-shot consume

    @Test("consume returns the pending request and clears the slot atomically — one-shot semantics")
    func consumeIsOneShot() {
        let defaults = makeDefaults()
        let request = PendingAIIntakeRequest(scenarioText: "Capture this once.")
        PendingAIIntakeRequestStore.write(request, to: defaults)

        let firstConsume = PendingAIIntakeRequestStore.consume(from: defaults)
        #expect(firstConsume == request)

        // Second consume must return nil — slot was cleared.
        let secondConsume = PendingAIIntakeRequestStore.consume(from: defaults)
        #expect(secondConsume == nil)

        // And read() must agree the slot is empty.
        let readAfter = PendingAIIntakeRequestStore.read(from: defaults)
        #expect(readAfter == nil)
    }

    @Test("write overrides any previously-pending request — last writer wins")
    func writeOverridesPreviousRequest() {
        let defaults = makeDefaults()
        PendingAIIntakeRequestStore.write(
            PendingAIIntakeRequest(scenarioText: "First."),
            to: defaults
        )
        PendingAIIntakeRequestStore.write(
            PendingAIIntakeRequest(scenarioText: "Second."),
            to: defaults
        )
        let readBack = PendingAIIntakeRequestStore.read(from: defaults)
        #expect(readBack?.scenarioText == "Second.")
    }

    // MARK: - Storage key namespace

    @Test("Storage key is namespaced under nomadfi.aiIntake — greppable across the codebase")
    func storageKeyIsNamespaced() {
        #expect(PendingAIIntakeRequest.storageKey.hasPrefix("nomadfi."))
        #expect(PendingAIIntakeRequest.storageKey.contains("aiIntake"))
    }

    @Test("Storage key is distinct from MainTabSelection.storageKey — no slot collision")
    func storageKeyIsDistinctFromTabKey() {
        #expect(PendingAIIntakeRequest.storageKey != MainTabSelection.storageKey)
    }
}
