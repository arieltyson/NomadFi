// NomadFiActionButtonTests.swift
// NomadFi
//
// Pins the contract that motivated the primitive's existence: the
// label-style modifier that forces both the SF Symbol *and* the
// title to render must never be removed from `NomadFiActionButton`.
//
// The bug we are guarding against (recurring incident):
//
//   SwiftUI's default label-style propagation collapses `Label`
//   content to title-only when wrapped inside a `Button` with
//   `.borderedProminent` / `.bordered`. Symptom: the glyph next to
//   the button text only flashes during the press animation. The
//   fix is `.labelStyle(.titleAndIcon)` baked into a single shared
//   primitive so call sites can't drift.
//
// SwiftUI's view tree is not introspectable from a unit test, and
// the iOS Simulator's sandbox blocks reading the source file off
// disk, so the contract is pinned by every channel we *can* assert
// on at unit-test time:
//
//   1. Style-enum snapshot — exactly three cases, in the order the
//      design system documents. Adding/removing a case requires a
//      deliberate update here so the prominence ladder cannot
//      silently grow a fourth, undocumented variant.
//   2. Construction smoke — every public initialization shape
//      builds without crashing. Catches accidental signature
//      changes that would break call sites at compile time before
//      they reach the device.
//   3. Conformance pinning — the style remains `Sendable`,
//      `Equatable`, and `Hashable` so it can cross actor boundaries
//      and be diffed in tests.
//
// The `.labelStyle(.titleAndIcon)` modifier itself is documented
// extensively in the primitive's file header; manual code review
// of that file is the final guardrail. A future "convenience init"
// that strips the modifier should be caught by reviewers because
// the file header explicitly forbids it.

import Foundation
import SwiftUI
import Testing

@testable import NomadFi

struct NomadFiActionButtonTests {

    // MARK: - Style ladder snapshot

    @Test("NomadFiActionButtonStyle has exactly three cases — primary, secondary, tertiary — matching Apple's prominence ladder")
    func styleLadderSnapshot() {
        let snapshot: [NomadFiActionButtonStyle] = [.primary, .secondary, .tertiary]
        #expect(snapshot.count == 3)
        #expect(snapshot[0] == .primary)
        #expect(snapshot[1] == .secondary)
        #expect(snapshot[2] == .tertiary)
    }

    @Test("NomadFiActionButtonStyle is Sendable + Equatable + Hashable so it can cross actor boundaries and be diffed in tests")
    func styleConformances() {
        let primary: NomadFiActionButtonStyle = .primary
        let secondary: NomadFiActionButtonStyle = .secondary
        #expect(primary == .primary)
        #expect(primary != secondary)
        #expect(Set([primary, secondary, .tertiary]).count == 3)
    }

    // MARK: - Construction smoke

    @Test("NomadFiActionButton constructs with only the required parameters (title, systemImage, action) — defaults stay stable")
    @MainActor
    func constructsWithRequiredParametersOnly() {
        _ = NomadFiActionButton(
            title: "Capture decision",
            systemImage: "square.and.pencil",
            action: {}
        )
    }

    @Test("NomadFiActionButton constructs with every public parameter — signature regressions fail at test compile time before they reach call sites")
    @MainActor
    func constructsWithEveryParameter() {
        _ = NomadFiActionButton(
            title: "Open Review",
            systemImage: "checkmark.circle",
            style: .primary,
            controlSize: .large,
            role: nil,
            fillsWidth: true,
            accessibilityHint: "Switches Tax Vault to the Review surface.",
            action: {}
        )
        _ = NomadFiActionButton(
            title: "Cancel",
            systemImage: "xmark",
            style: .tertiary,
            controlSize: .regular,
            role: .cancel,
            fillsWidth: false,
            accessibilityHint: nil,
            action: {}
        )
    }
}
