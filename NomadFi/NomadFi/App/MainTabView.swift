import SwiftData
import SwiftUI

/// The app's primary tab bar.
///
/// NomadFi is a decision assistant, not a manual ledger — the tabs
/// here are limited to the surfaces that drive day-to-day decisions:
/// Dashboard for net worth and scenarios, Subscriptions for recurring
/// spend arbitrage, and Settings for configuration plus optional
/// manual tools (Ledger, Tax Vault). Ledger and Tax Vault remain
/// fully functional; they just no longer anchor primary navigation
/// until automatic aggregation and stronger tax-planning flows exist.
struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "globe") {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Subscriptions", systemImage: "arrow.triangle.2.circlepath") {
                SubscriptionsView()
            }

            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(
            for: [
                Currency.self,
                JurisdictionProfile.self,
                Account.self,
                Transaction.self,
                ExchangeRate.self,
                TaxDocument.self,
                Subscription.self,
                Budget.self,
            ],
            inMemory: true
        )
}
