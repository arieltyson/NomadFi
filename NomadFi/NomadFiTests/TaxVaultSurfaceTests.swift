// TaxVaultSurfaceTests.swift
// NomadFi
//
// Small value-level coverage for the Tax Vault peer-surface
// enum. The enum drives both the segmented switcher and the
// shell's view-dispatch, so the test guards the two things that
// actually matter: the surface set is complete (Review / Learn /
// Archive, no more, no fewer) and every label is safe for
// user-facing copy.

import Foundation
import Testing

@testable import NomadFi

struct TaxVaultSurfaceTests {

    // MARK: - Set

    @Test("Peer surfaces are exactly Review, Learn, Archive — no more, no fewer")
    func peerSurfaceSetIsStable() {
        let expected: Set<TaxVaultSurface> = [.review, .learn, .archive]
        #expect(Set(TaxVaultSurface.allCases) == expected)
    }

    @Test("Every surface has a non-empty title, SF Symbol, and a11y label")
    func surfaceMetadataIsComplete() {
        for surface in TaxVaultSurface.allCases {
            #expect(!surface.title.isEmpty)
            #expect(!surface.systemImage.isEmpty)
            #expect(!surface.accessibilityLabel.isEmpty)
        }
    }

    // MARK: - Copy guard

    @Test("Surface labels and accessibility copy stay calm — no marketing or banned vocabulary")
    func copyGuardOnSurfaceVocabulary() {
        // "XP" is intentionally omitted from the substring check
        // because it collides with "export" — a legitimate Archive
        // word. The concept is still banned in the authoring rules
        // above; this guard sticks to strings that won't false-
        // positive on legitimate surface vocabulary.
        let bannedPhrases: [String] = [
            "compliant",
            "streak",
            "you qualify",
            "this qualifies",
            "tax advice",
            "legal advice",
            "immigration advice",
            "gamify",
            "points",
        ]
        var inspected: [String] = []
        for surface in TaxVaultSurface.allCases {
            inspected.append(surface.title)
            inspected.append(surface.accessibilityLabel)
        }
        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' in surface copy: \(copy)"
                )
            }
        }
    }
}
