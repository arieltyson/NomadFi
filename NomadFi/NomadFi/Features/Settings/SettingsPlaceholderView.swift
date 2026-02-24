import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Settings",
            systemImage: "gearshape",
            description: Text("Manage jurisdictions, currencies, privacy, and account preferences.")
        )
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView()
    }
}
