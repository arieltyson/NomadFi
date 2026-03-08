import Foundation
import WidgetKit

struct NomadFiDashboardWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DashboardWidgetSnapshot

    static let placeholder = NomadFiDashboardWidgetEntry(
        date: Date.now,
        snapshot: .placeholder
    )
}
