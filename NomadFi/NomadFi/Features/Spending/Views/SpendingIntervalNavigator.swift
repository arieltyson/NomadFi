import SwiftUI

/// Names the months or year being shown, between arrows that step back
/// and forward. Tapping the name lists every interval with purchases, to
/// jump straight to one.
struct SpendingIntervalNavigator: View {

    let viewModel: SpendingViewModel

    var body: some View {
        let interval = viewModel.interval
        HStack(spacing: SpacingTokens.small) {
            Button("Previous", systemImage: "chevron.backward") {
                viewModel.step(by: -1)
            }
            .disabled(!viewModel.canGoBack)

            Spacer(minLength: .zero)

            Menu {
                Picker("Show", selection: Binding(get: { interval }, set: viewModel.show)) {
                    ForEach(viewModel.selectableIntervals()) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                HStack(spacing: SpacingTokens.xxSmall) {
                    Text(interval.title)
                        .font(TypographyTokens.sectionHeader)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(TypographyTokens.caption.bold())
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.primary)
            }
            .accessibilityLabel("Showing \(interval.title)")
            .accessibilityHint("Choose another \(Text(viewModel.period.title).textCase(.lowercase)).")

            Spacer(minLength: .zero)

            Button("Next", systemImage: "chevron.forward") {
                viewModel.step(by: 1)
            }
            .disabled(!viewModel.canGoForward())
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .frame(minHeight: SizeTokens.minimumTapTarget)
        .sensoryFeedback(.selection, trigger: interval)
        .animation(AnimationTokens.snappy, value: interval)
    }
}
