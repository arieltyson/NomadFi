// DashboardEmptyStateView.swift
// NomadFi
//
// The Dashboard before any account exists.

import SwiftUI

/// A brand-green silhouette of the Dashboard with one sentence saying
/// where accounts come from. The silhouette carries the brand; the words
/// carry the instruction.
struct DashboardEmptyStateView: View {

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: SpacingTokens.large) {
                DashboardSilhouette()
                Text("No Accounts Yet")
                    .font(.title2)
                    .bold()
            }
        } description: {
            Text("Add an account or connect your bank in Settings to see your net worth.")
        }
    }
}

#Preview {
    DashboardEmptyStateView()
}
