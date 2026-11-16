import SwiftUI

/// Says how many purchases a breakdown left out because they were in
/// another currency. Shows nothing when none were.
struct SpendingCurrencyNote: View {

    let otherCurrencyCount: Int

    var body: some View {
        if otherCurrencyCount > 0 {
            Text("Leaves out ^[\(otherCurrencyCount) purchase](inflect: true) in other currencies.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
