import Foundation

/// Shared constants for the app/widget data channel.
enum NomadFiWidgetSharedConstants {
    static let appGroupIdentifier = "group.com.arieljtyson.NomadFi"
    static let dashboardSnapshotKey = "dashboard_widget_snapshot_v1"
}

/// Direction of the latest net-worth movement shown in widgets.
enum WidgetTrendDirection: String, Codable, Sendable {
    case up
    case down
    case flat
}

/// Lightweight account payload rendered in widget medium family.
struct WidgetAccountSummary: Codable, Sendable {
    let id: String
    let name: String
    let institutionName: String
    let balance: Double
    let currencyCode: String
}

/// Snapshot persisted by the app and consumed by WidgetKit timelines.
struct DashboardWidgetSnapshot: Codable, Sendable {
    let generatedAt: Date
    let totalNetWorth: Double
    let homeCurrencyCode: String
    let trendDirection: WidgetTrendDirection
    let trendPercentage: Double
    let topAccounts: [WidgetAccountSummary]
}
