import SwiftUI
import WidgetKit

struct NomadFiLockScreenWidget: Widget {

    let kind = "NomadFiLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NomadFiWidgetConfigurationIntent.self,
            provider: NomadFiDashboardTimelineProvider()
        ) { entry in
            NomadFiLockScreenWidgetEntryView(entry: entry)
                // Balances and account names are redacted while the iPhone is locked
                // (Lock Screen, StandBy) and shown once it is unlocked.
                .privacySensitive()
        }
        .configurationDisplayName("Net Worth on Lock Screen")
        .description("See your current global net worth at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}
