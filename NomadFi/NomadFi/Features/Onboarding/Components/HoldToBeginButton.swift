// HoldToBeginButton.swift
// NomadFi
//
// A press-and-hold button that turns finishing setup into a small ritual.

import SwiftUI

/// Hold to commit. Brand green fills the capsule while it is held and a
/// rumble rises with it; letting go early springs it back with a "keep
/// holding" nudge; completing it blooms, with a burst felt and seen at
/// the same instant. VoiceOver, Voice Control and Switch Control activate
/// it directly, without holding.
struct HoldToBeginButton: View {

    let title: LocalizedStringKey
    let accessibilityHint: LocalizedStringKey
    let action: () -> Void

    @Environment(\.hapticConductor) private var conductor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var height = SizeTokens.holdButtonHeight

    @State private var progress = 0.0
    @State private var isComplete = false
    @State private var holdStartedAt: Date?
    @State private var rumble: Task<Void, Never>?

    var body: some View {
        ZStack {
            Capsule()
                .fill(ColorTokens.tintedFill(ColorTokens.actionTint, contrast: contrast))

            Capsule()
                .fill(ColorTokens.actionTint)
                .scaleEffect(x: progress, anchor: .leading)

            HoldToBeginLabel(title: title, progress: progress)
        }
        .frame(height: height)
        .overlay { HoldToBeginBloom(isActive: isComplete && !reduceMotion) }
        .contentShape(.capsule)
        .onLongPressGesture(
            minimumDuration: BloomCadence.hold,
            maximumDistance: SpacingTokens.xLarge,
            perform: complete,
            onPressingChanged: pressingChanged
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { complete() }
    }

    private func pressingChanged(_ isPressing: Bool) {
        guard !isComplete else { return }
        if isPressing {
            holdStartedAt = .now
            conductor?.beginHold()
            withAnimation(.linear(duration: BloomCadence.hold)) { progress = 1 }
            rumble = Task { await swell() }
        } else {
            rumble?.cancel()
            conductor?.endHold()
            if let start = holdStartedAt, Date.now.timeIntervalSince(start) < BloomCadence.hold / 3 {
                conductor?.play(.nudge)
            }
            holdStartedAt = nil
            withAnimation(AnimationTokens.entrance) { progress = 0 }
        }
    }

    /// Raises the rumble in step with the fill until the hold ends.
    private func swell() async {
        while !Task.isCancelled, let start = holdStartedAt {
            conductor?.updateHold(progress: min(Date.now.timeIntervalSince(start) / BloomCadence.hold, 1))
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    private func complete() {
        guard !isComplete else { return }
        rumble?.cancel()
        conductor?.endHold()
        conductor?.play(.bloom)
        holdStartedAt = nil
        progress = 1
        isComplete = true
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : BloomCadence.burst + BloomCadence.fade / 2))
            action()
        }
    }
}

/// The title in the action colour, overlaid by the same title in white
/// masked to the fill, so its colour flips exactly where the fill passes.
private struct HoldToBeginLabel: View {

    let title: LocalizedStringKey
    let progress: Double

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(ColorTokens.actionTint)
            .overlay {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTokens.onActionTint)
                    .mask(alignment: .leading) {
                        Rectangle().scaleEffect(x: progress, anchor: .leading)
                    }
            }
            .padding(.horizontal, SpacingTokens.large)
    }
}

/// A ring and a burst of particles thrown out from the button's centre,
/// shown once the hold completes.
private struct HoldToBeginBloom: View {

    let isActive: Bool

    var body: some View {
        if isActive {
            HoldToBeginBurst()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct HoldToBeginBurst: View {

    private static let particles = 10
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Capsule()
                .stroke(ColorTokens.actionTint, lineWidth: SpacingTokens.xxxSmall)
                .scaleEffect(isExpanded ? 1.25 : 1)
                .opacity(isExpanded ? 0 : 1)

            ForEach(0..<Self.particles, id: \.self) { index in
                let angle = Angle.degrees(Double(index) / Double(Self.particles) * 360)
                Circle()
                    .fill(ColorTokens.actionTint)
                    .frame(width: SpacingTokens.xSmall, height: SpacingTokens.xSmall)
                    .offset(
                        x: isExpanded ? cos(angle.radians) * SpacingTokens.xxLarge * 2 : 0,
                        y: isExpanded ? sin(angle.radians) * SpacingTokens.xxLarge : 0
                    )
                    .scaleEffect(isExpanded ? 0.3 : 1)
                    .opacity(isExpanded ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: BloomCadence.burst + BloomCadence.fade)) { isExpanded = true }
        }
    }
}

#Preview {
    HoldToBeginButton(title: "Hold to Begin", accessibilityHint: "Finishes setup") { }
        .padding()
        .environment(\.hapticConductor, HapticConductor())
}
