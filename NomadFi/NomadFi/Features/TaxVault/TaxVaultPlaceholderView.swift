import SwiftUI

struct TaxVaultPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Tax Vault",
            systemImage: "doc.text.viewfinder",
            description: Text("Receipt scanning and tax exports are planned for Phase 4.")
        )
        .navigationTitle("Tax Vault")
    }
}

#Preview {
    NavigationStack {
        TaxVaultPlaceholderView()
    }
}
