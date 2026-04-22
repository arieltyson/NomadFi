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
///
/// Tab selection is persisted via `@AppStorage` so an App Intent can
/// write ``MainTabSelection/storageKey`` before `openAppWhenRun`
/// activates the app, and the tab bar honours the requested route
/// reactively on first appearance.
struct MainTabView: View {

    @AppStorage(MainTabSelection.storageKey)
    private var storedSelection: MainTabSelection = .default

    var body: some View {
        TabView(selection: $storedSelection) {
            Tab(
                "Dashboard",
                systemImage: "globe",
                value: MainTabSelection.dashboard
            ) {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab(
                "Decisions",
                systemImage: "scale.3d",
                value: MainTabSelection.decisions
            ) {
                NavigationStack {
                    DecisionAssistantView()
                }
            }

            Tab(
                "Settings",
                systemImage: "gearshape",
                value: MainTabSelection.settings
            ) {
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
