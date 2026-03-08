import AppIntents
import Foundation
import WidgetKit

struct NomadFiDashboardTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = NomadFiDashboardWidgetEntry
    typealias Intent = NomadFiWidgetConfigurationIntent

    private let snapshotStore = NomadFiWidgetSnapshotStore()

    func placeholder(in context: Context) -> Entry {
        .placeholder
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        let snapshot = snapshotStore.load()
        return Entry(date: Date.now, snapshot: snapshot)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = Entry(date: Date.now, snapshot: snapshotStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date.now)
            ?? Date.now.addingTimeInterval(900)

        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}
