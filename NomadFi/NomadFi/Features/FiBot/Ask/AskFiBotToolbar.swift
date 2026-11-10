// AskFiBotToolbar.swift
// NomadFi
//
// Ask FiBot's two secondary actions, kept in the toolbar.

import SwiftUI

/// Start over, once there is something to clear, and a menu holding
/// the purchase check.
struct AskFiBotToolbar: ToolbarContent {

    let hasConversation: Bool
    let onStartOver: () -> Void
    let onCheckPurchase: () -> Void

    var body: some ToolbarContent {
        if hasConversation {
            ToolbarItem(placement: .topBarLeading) {
                Button("New Conversation", systemImage: "square.and.pencil", action: onStartOver)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("More", systemImage: "ellipsis") {
                Button("Check a Purchase", systemImage: "checkmark.shield", action: onCheckPurchase)
            }
        }
    }
}
