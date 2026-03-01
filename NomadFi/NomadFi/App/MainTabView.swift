import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "globe") {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Ledger", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    LedgerView()
                }
            }

            Tab("Tax Vault", systemImage: "doc.text.viewfinder") {
                TaxVaultView()
            }

            Tab("Subscriptions", systemImage: "arrow.triangle.2.circlepath") {
                SubscriptionsView()
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
