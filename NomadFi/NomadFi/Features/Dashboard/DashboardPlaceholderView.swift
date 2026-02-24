import SwiftUI

struct DashboardPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Dashboard",
            systemImage: "globe",
            description: Text("Your global net worth at a glance. Dashboard implementation starts in Phase 2.")
        )
        .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack {
        DashboardPlaceholderView()
    }
}
