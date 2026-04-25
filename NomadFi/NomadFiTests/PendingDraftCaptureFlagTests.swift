// PendingDraftCaptureFlagTests.swift
// NomadFi
//
// Pins the contract of the typed-form launch flag — the
// sentinel-style sibling of `PendingAIIntakeRequestStore` used
// by `StartDraftCaptureIntent` and `DraftCaptureControlWidget`
// to ask the in-app `DecisionAssistantView` to present the
// typed `DecisionDraftFormView`.
//
// Three contract guarantees:
//
//   1. Round-trip: `write(to:)` followed by `read(from:)`
//      returns `true`; an unwritten slot reads as `false`.
//   2. One-shot consume: `consume(from:)` returns the value
//      *and* clears the slot atomically — calling it twice
//      returns the value once and `false` thereafter.
//   3. Idempotent clear: `clear(in:)` always leaves the slot
//      empty regardless of prior state.
//
// All tests use a fresh `UserDefaults(suiteName:)` so they
// never pollute the production routing slot.

import Foundation
import Testing

@testable import NomadFi

struct PendingDraftCaptureFlagTests {

    // MARK: - Helpers

    private func makeDefaults(file: String = #fileID, line: Int = #line) -> UserDefaults {
        let suiteName = "nomadfi.tests.PendingDraftCaptureFlag.\(file).\(line).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        guard let defaults else {
            fatalError("Could not allocate UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Round-trip

    @Test("Empty slot reads as false — defensive baseline")
    func emptySlotReadsAsFalse() {
        let defaults = makeDefaults()
        #expect(PendingDraftCaptureFlag.read(from: defaults) == false)
    }

    @Test("write then read returns true — basic flag contract")
    func writeThenReadReturnsTrue() {
        let defaults = makeDefaults()
        PendingDraftCaptureFlag.write(to: defaults)
        #expect(PendingDraftCaptureFlag.read(from: defaults) == true)
    }

    @Test("read does not mutate the slot — repeated reads return the same value")
    func readIsIdempotent() {
        let defaults = makeDefaults()
        PendingDraftCaptureFlag.write(to: defaults)
        let first = PendingDraftCaptureFlag.read(from: defaults)
        let second = PendingDraftCaptureFlag.read(from: defaults)
        #expect(first == true)
        #expect(second == true)
    }

    @Test("clear leaves the slot empty regardless of prior state")
    func clearIsTotal() {
        let defaults = makeDefaults()
        PendingDraftCaptureFlag.write(to: defaults)
        PendingDraftCaptureFlag.clear(in: defaults)
        #expect(PendingDraftCaptureFlag.read(from: defaults) == false)

        // Clearing an empty slot is also a no-op.
        PendingDraftCaptureFlag.clear(in: defaults)
        #expect(PendingDraftCaptureFlag.read(from: defaults) == false)
    }

    // MARK: - One-shot consume

    @Test("consume returns the flag value and clears the slot atomically — control taps cannot re-trigger the launch")
    func consumeIsOneShot() {
        let defaults = makeDefaults()
        PendingDraftCaptureFlag.write(to: defaults)

        let first = PendingDraftCaptureFlag.consume(from: defaults)
        #expect(first == true)

        let second = PendingDraftCaptureFlag.consume(from: defaults)
        #expect(second == false)

        #expect(PendingDraftCaptureFlag.read(from: defaults) == false)
    }

    @Test("consume on an empty slot returns false without side effects")
    func consumeOnEmptySlotReturnsFalse() {
        let defaults = makeDefaults()
        #expect(PendingDraftCaptureFlag.consume(from: defaults) == false)
    }

    // MARK: - Storage key namespace

    @Test("Storage key is namespaced under nomadfi.draftCapture — greppable across the codebase")
    func storageKeyIsNamespaced() {
        #expect(PendingDraftCaptureFlag.storageKey.hasPrefix("nomadfi."))
        #expect(PendingDraftCaptureFlag.storageKey.contains("draftCapture"))
    }

    @Test("Storage key is distinct from the AI-intake and tab-selection keys — no slot collision")
    func storageKeyIsDistinct() {
        #expect(PendingDraftCaptureFlag.storageKey != PendingAIIntakeRequest.storageKey)
        #expect(PendingDraftCaptureFlag.storageKey != MainTabSelection.storageKey)
    }
}
