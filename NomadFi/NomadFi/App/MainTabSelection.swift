// MainTabSelection.swift
// NomadFi
//
// Stable, persistable identifier for each bottom-tab surface. The
// raw value is what App Intents write to `UserDefaults` when they
// need the app to open straight to a specific tab (the Decision
// Assistant today). Keeping it as a tiny, Sendable enum lets both
// `MainTabView` and intent code agree on valid values without
// stringly-typed drift.

import Foundation

/// The three primary surfaces on NomadFi's bottom tab bar.
///
/// Intentionally minimal — this type exists so App Intents can route
/// a launch (`openAppWhenRun = true`) straight to the Decision
/// Assistant without fragile string matching.
enum MainTabSelection: String, CaseIterable, Sendable, Hashable {

    case dashboard
    case decisions
    case settings

    /// The tab the app should open to at cold start, unless a
    /// pending override has been written by an App Intent.
    static let `default`: MainTabSelection = .dashboard

    /// Shared `UserDefaults` key used to hand a tab selection from
    /// an App Intent to ``MainTabView`` at app launch. The app reads
    /// the key through `@AppStorage` so writes from an intent flow
    /// in reactively.
    static let storageKey: String = "nomadfi.mainTab.selection"
}
