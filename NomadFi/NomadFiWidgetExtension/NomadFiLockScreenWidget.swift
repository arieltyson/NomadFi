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
        }
        .configurationDisplayName("Net Worth on Lock Screen")
        .description("See your current global net worth at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}
