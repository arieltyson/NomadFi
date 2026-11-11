// SubscriptionsEmptyStateView.swift
// NomadFi
//
// What Subscriptions shows before any exist.

import SwiftUI

/// A quiet empty state. Adding a subscription is the toolbar's +, so the
/// empty state only explains where subscriptions come from.
struct SubscriptionsEmptyStateView: View {

    var body: some View {
        ContentUnavailableView {
            Label("No Subscriptions", systemImage: "arrow.triangle.2.circlepath")
        } description: {
            Text("Recurring charges in your transactions appear here. To add one yourself, tap +.")
        }
    }
}

#Preview {
    SubscriptionsEmptyStateView()
}
