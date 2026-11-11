// SizeTokens.swift
// NomadFi
//
// Base sizes for components. Scale them with `@ScaledMetric` so they
// grow with Dynamic Type.

import SwiftUI

/// Base component sizes, in points at the default text size.
enum SizeTokens {

    /// The minimum height of a tile in a grid of cards: a symbol above
    /// a two-line title, so tiles stay one height whatever their title.
    static let tileMinimumHeight: CGFloat = 136

    /// The smallest comfortable tap target (Apple HIG: 44 × 44 pt).
    static let minimumTapTarget: CGFloat = 44
}
