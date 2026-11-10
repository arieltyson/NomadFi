import SwiftData
import SwiftUI

/// The app's primary tab bar.
///
/// A Dashboard that grounds the user in their money context, Ask
/// FiBot for private questions about it, the Tools (Decisions and
/// the optional manual workflows), and Settings.
///
/// Tab selection is persisted via `@AppStorage` so an App Intent
/// running in `.foreground(.immediate)` mode can write
/// ``MainTabSelection/storageKey`` before the system brings the app
/// forward, and the tab bar honours the requested route reactively
/// on first appearance.
///
/// The store is the App Group shared suite via
/// ``AppRoutingDefaults/shared`` so a tap from the widget
/// extension's `ControlWidgetButton` (whose `perform()` body may
/// run in the widget process) writes to the same suite the
/// main-app `@AppStorage` reads from.
struct MainTabView: View {

    @AppStorage(MainTabSelection.storageKey, store: AppRoutingDefaults.shared)
    private var storedSelection: MainTabSelection = .default

    var body: some View {
        TabView(selection: $storedSelection) {
            ForEach(MainTabSelection.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    MainTabRoot(tab: tab)
                }
            }
        }
    }
}

/// The root screen of each tab, each in its own navigation stack.
/// Tools owns its stack so a launch route can push a tool onto it.
private struct MainTabRoot: View {

    let tab: MainTabSelection

    var body: some View {
        switch tab {
        case .dashboard: NavigationStack { DashboardView() }
        case .fiBot: NavigationStack { AskFiBotView() }
        case .tools: ToolsView()
        case .settings: NavigationStack { SettingsView() }
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
                DecisionDraftRecord.self,
                PurchaseDecisionRecord.self,
            ],
            inMemory: true
        )
}
