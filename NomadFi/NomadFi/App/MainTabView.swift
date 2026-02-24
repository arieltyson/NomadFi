import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "globe") {
                NavigationStack {
                    DashboardPlaceholderView()
                }
            }

            Tab("Ledger", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    LedgerPlaceholderView()
                }
            }

            Tab("Tax Vault", systemImage: "doc.text.viewfinder") {
                NavigationStack {
                    TaxVaultPlaceholderView()
                }
            }

            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsPlaceholderView()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [
            Currency.self,
            JurisdictionProfile.self,
            Account.self,
            Transaction.self,
            ExchangeRate.self,
            TaxDocument.self,
            Subscription.self,
            Budget.self,
        ], inMemory: true)
}
