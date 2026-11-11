import SwiftUI
import WidgetKit

struct NomadFiDashboardWidget: Widget {

    let kind = "NomadFiDashboardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NomadFiWidgetConfigurationIntent.self,
            provider: NomadFiDashboardTimelineProvider()
        ) { entry in
            NomadFiDashboardWidgetEntryView(entry: entry)
                // Balances and account names are redacted while the iPhone is locked
                // (Lock Screen, StandBy) and shown once it is unlocked.
                .privacySensitive()
        }
        .configurationDisplayName("Global Net Worth")
        .description("Track your cross-border net worth with live account context.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
