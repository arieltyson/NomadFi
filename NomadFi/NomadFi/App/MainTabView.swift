import SwiftData
import SwiftUI

/// The app's primary tab bar.
///
/// NomadFi is a cross-border financial decision assistant, so the
/// bottom tabs surface exactly the three workflows that matter every
/// day: a Dashboard that grounds the user in their money context, a
/// Decision Assistant that routes them into source-backed scenario
/// recommendations, and a Settings hub that hosts financial setup
/// plus optional companion tools (Subscriptions, Ledger, Tax Vault).
///
/// Subscriptions, Ledger, and Tax Vault live under Settings →
/// Advanced Tools rather than on the tab bar — they're valuable but
/// secondary to the decision surface.
struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "globe") {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Decisions", systemImage: "scale.3d") {
                NavigationStack {
                    DecisionAssistantView()
                }
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
                ScenarioDecisionRecord.self,
            ],
            inMemory: true
        )
}
