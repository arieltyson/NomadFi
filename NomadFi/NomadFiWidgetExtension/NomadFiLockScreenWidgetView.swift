import SwiftUI
import WidgetKit

struct NomadFiLockScreenWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family

    let entry: NomadFiDashboardWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            NomadFiCircularLockScreenView(snapshot: entry.snapshot)
        case .accessoryInline:
            NomadFiInlineLockScreenView(snapshot: entry.snapshot)
        default:
            NomadFiInlineLockScreenView(snapshot: entry.snapshot)
        }
    }
}

private struct NomadFiCircularLockScreenView: View {

    let snapshot: DashboardWidgetSnapshot

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "globe")
                .font(.caption2)
            Text(compactAmount)
                .font(.caption2)
                .bold()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .widgetAccentable()
    }

    private var compactAmount: String {
        snapshot.totalNetWorth.formatted(.number.notation(.compactName))
    }
}

private struct NomadFiInlineLockScreenView: View {

    let snapshot: DashboardWidgetSnapshot

    var body: some View {
        Text("Net worth \(snapshot.totalNetWorth, format: .currency(code: snapshot.homeCurrencyCode))")
    }
}
