import SwiftUI

struct LedgerPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Ledger",
            systemImage: "list.bullet.rectangle",
            description: Text("Cross-border transactions and real-cost insights arrive in Phase 3.")
        )
        .navigationTitle("Ledger")
    }
}

#Preview {
    NavigationStack {
        LedgerPlaceholderView()
    }
}
