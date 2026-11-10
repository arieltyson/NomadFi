// DecisionsRoute.swift
// NomadFi
//
// The Decision Assistant lives on the Tools tab, so opening it from
// Siri, Shortcuts, a Control or the Action button takes two writes:
// select the Tools tab, then ask the Tools stack to push Decisions.

import Foundation

/// Routes a launch to the Decision Assistant on the Tools tab.
///
/// Both writes go to the App Group suite
/// (``AppRoutingDefaults/shared``) so they are observed whichever
/// process ran the intent. ``ToolsView`` consumes the pending tool
/// and clears it, so the route fires once.
enum DecisionsRoute {

    /// Selects the Tools tab and queues the Decision Assistant.
    @MainActor
    static func request(in defaults: UserDefaults = AppRoutingDefaults.shared) {
        defaults.set(MainTabSelection.tools.rawValue, forKey: MainTabSelection.storageKey)
        defaults.set(Tool.decisions.rawValue, forKey: Tool.pendingStorageKey)
    }
}
