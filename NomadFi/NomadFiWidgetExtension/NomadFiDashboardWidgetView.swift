import SwiftUI
import WidgetKit

private enum WidgetSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
}

struct NomadFiDashboardWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family

    let entry: NomadFiDashboardWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            NomadFiSmallDashboardWidgetView(snapshot: entry.snapshot)
        case .systemMedium:
            NomadFiMediumDashboardWidgetView(snapshot: entry.snapshot)
        default:
            NomadFiSmallDashboardWidgetView(snapshot: entry.snapshot)
        }
    }
}

private struct NomadFiSmallDashboardWidgetView: View {

    let snapshot: DashboardWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.small) {
            HStack {
                Label("Net Worth", systemImage: "globe.americas")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: WidgetSpacing.small)

                TrendBadge(snapshot: snapshot)
            }

            Text(snapshot.totalNetWorth, format: .money(code: snapshot.homeCurrencyCode))
                .font(.title3)
                .bold()
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text("Updated \(snapshot.generatedAt, format: .dateTime.hour().minute())")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

private struct NomadFiMediumDashboardWidgetView: View {

    let snapshot: DashboardWidgetSnapshot

    var body: some View {
        HStack(spacing: WidgetSpacing.medium) {
            VStack(alignment: .leading, spacing: WidgetSpacing.small) {
                Label("Global Net Worth", systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(snapshot.totalNetWorth, format: .money(code: snapshot.homeCurrencyCode))
                    .font(.title3)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                TrendLabel(snapshot: snapshot)
            }

            Divider()

            VStack(alignment: .leading, spacing: WidgetSpacing.small) {
                Text("Top Accounts")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(snapshot.topAccounts.prefix(2), id: \.id) { account in
                    AccountSummaryRow(account: account)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

private struct AccountSummaryRow: View {

    let account: WidgetAccountSummary

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.xSmall) {
            Text(account.name)
                .font(.caption)
                .lineLimit(1)

            Text(account.balance, format: .money(code: account.currencyCode))
                .font(.footnote)
                .bold()
                .foregroundStyle(.secondary)
        }
    }
}

private struct TrendBadge: View {

    let snapshot: DashboardWidgetSnapshot

    var body: some View {
        HStack(spacing: WidgetSpacing.xSmall) {
            Image(systemName: trendSymbol)
            Text(abs(snapshot.trendPercentage), format: .number.precision(.fractionLength(2)))
            Text("%")
        }
        .font(.caption2)
        .foregroundStyle(trendColor)
    }

    private var trendSymbol: String {
        switch snapshot.trendDirection {
        case .up:
            "arrow.up.right"
        case .down:
            "arrow.down.right"
        case .flat:
            "minus"
        }
    }

    private var trendColor: Color {
        switch snapshot.trendDirection {
        case .up:
            .green
        case .down:
            .red
        case .flat:
            .secondary
        }
    }
}

private struct TrendLabel: View {

    let snapshot: DashboardWidgetSnapshot

    var body: some View {
        HStack(spacing: WidgetSpacing.xSmall) {
            Image(systemName: trendSymbol)
            Text(trendText)
        }
        .font(.caption2)
        .foregroundStyle(trendColor)
    }

    private var trendText: String {
        let percent = abs(snapshot.trendPercentage).formatted(
            .number.precision(.fractionLength(2))
        )
        return "\(percent)%"
    }

    private var trendSymbol: String {
        switch snapshot.trendDirection {
        case .up:
            "arrow.up.right"
        case .down:
            "arrow.down.right"
        case .flat:
            "minus"
        }
    }

    private var trendColor: Color {
        switch snapshot.trendDirection {
        case .up:
            .green
        case .down:
            .red
        case .flat:
            .secondary
        }
    }
}
