import Foundation

/// Shared constants for app-group communication with NomadFi widgets.
enum NomadFiWidgetSharedConstants {
    static let appGroupIdentifier = "group.com.arieljtyson.NomadFi"
    static let dashboardSnapshotKey = "dashboard_widget_snapshot_v1"
}

enum WidgetTrendDirection: String, Codable, Sendable {
    case up
    case down
    case flat
}

struct WidgetAccountSummary: Codable, Sendable {
    let id: String
    let name: String
    let institutionName: String
    let balance: Double
    let currencyCode: String
}

struct DashboardWidgetSnapshot: Codable, Sendable {
    let generatedAt: Date
    let totalNetWorth: Double
    let homeCurrencyCode: String
    let trendDirection: WidgetTrendDirection
    let trendPercentage: Double
    let topAccounts: [WidgetAccountSummary]

    static let placeholder = DashboardWidgetSnapshot(
        generatedAt: Date.now,
        totalNetWorth: 67_215.75,
        homeCurrencyCode: "USD",
        trendDirection: .up,
        trendPercentage: 1.8,
        topAccounts: [
            WidgetAccountSummary(
                id: "chase-checking",
                name: "Chase Checking",
                institutionName: "JPMorgan Chase",
                balance: 8_450.12,
                currencyCode: "USD"
            ),
            WidgetAccountSummary(
                id: "wise-cad",
                name: "Wise CAD",
                institutionName: "Wise",
                balance: 5_200.44,
                currencyCode: "CAD"
            ),
        ]
    )
}
