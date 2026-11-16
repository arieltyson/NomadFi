import SwiftUI

/// The pinned day heading above each group of ledger rows.
struct LedgerDateSectionHeader: View {

    let date: Date

    var body: some View {
        Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    LedgerDateSectionHeader(date: .now)
}
