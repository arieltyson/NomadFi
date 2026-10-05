// LoadingIndicator.swift
// NomadFi
//
// A progress indicator for passive reads that stays out of sight
// unless the wait is long enough to notice.

import SwiftUI

/// A progress indicator for reading data, revealed only after a short
/// delay.
///
/// Most reads finish within a frame or two. An indicator that appears
/// for that long never reads as progress, only as a flicker between
/// one screen and the next. The space is held from the start, so the
/// indicator fades in without moving anything.
///
/// Not for actions the person started themselves — scanning, saving,
/// unlocking: those should acknowledge the tap at once with a plain
/// `ProgressView`.
struct LoadingIndicator: View {

    /// Waits shorter than this pass without an indicator.
    static let revealDelay: Duration = .milliseconds(500)

    private let title: LocalizedStringKey
    @State private var isRevealed = false

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        ProgressView(title)
            .opacity(isRevealed ? 1 : 0)
            .animation(.default, value: isRevealed)
            .task {
                do {
                    try await Task.sleep(for: Self.revealDelay)
                    isRevealed = true
                } catch {}
            }
    }
}

#Preview {
    LoadingIndicator("Loading account")
}
