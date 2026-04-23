// TaxEducationViewModel.swift
// NomadFi
//
// Observable wrapper around `TaxEducationSelector`. Holds the
// region bundles the UI renders and the currently-selected
// lesson for the detail sheet. No persistence, no progress
// tracking in this slice.

import Foundation
import SwiftUI

/// Observable state holder for the Tax Vault education surface.
@MainActor
@Observable
final class TaxEducationViewModel {

    // MARK: - State

    /// Region bundles in the order the selector picked them —
    /// home first, then other active jurisdictions.
    var regionBundles: [TaxEducationRegionBundle] = []

    /// Lesson currently open in the detail sheet. The sheet
    /// presentation binds to `selection != nil`.
    var selection: TaxEducationLesson?

    // MARK: - Refresh

    /// Rebuilds `regionBundles` from the user's active
    /// jurisdictions. Called from the Tax Vault view's
    /// `.task(id:)` so it re-runs when the query changes.
    func refresh(from jurisdictions: [JurisdictionProfile]) {
        regionBundles = TaxEducationSelector.regionBundles(for: jurisdictions)
    }

    // MARK: - Selection

    func select(_ lesson: TaxEducationLesson) {
        selection = lesson
    }

    func clearSelection() {
        selection = nil
    }

    // MARK: - Derived

    var hasContent: Bool {
        !regionBundles.isEmpty
    }
}
