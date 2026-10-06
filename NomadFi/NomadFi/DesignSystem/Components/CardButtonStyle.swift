// CardButtonStyle.swift
// NomadFi
//
// Press feedback for a whole card that acts as a button or link.

import SwiftUI

/// Lets a card answer a press: it settles slightly under the finger,
/// or dims instead when Reduce Motion is on.
struct CardButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far a pressed card settles.
    private static let pressedScale = 0.97
    /// How far a pressed card dims under Reduce Motion.
    private static let pressedOpacity = 0.7

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Self.pressedScale : 1)
            .opacity(configuration.isPressed && reduceMotion ? Self.pressedOpacity : 1)
            .animation(reduceMotion ? nil : AnimationTokens.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardButtonStyle {

    /// Press feedback for a card: `.buttonStyle(.card)`.
    static var card: CardButtonStyle { CardButtonStyle() }
}
