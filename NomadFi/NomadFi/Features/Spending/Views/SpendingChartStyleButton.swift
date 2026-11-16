import SwiftUI

/// The toolbar button that switches the Spending charts between a wheel
/// and bars. The choice is remembered.
struct SpendingChartStyleButton: View {

    @Binding var style: SpendingChartStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : AnimationTokens.standard) {
                style = style.toggled
            }
        } label: {
            Label {
                Text(style.toggled.switchTitle)
            } icon: {
                Image(systemName: style.toggled.systemImage)
            }
        }
        .sensoryFeedback(.selection, trigger: style)
    }
}
