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

    /// The height of a full-width, press-and-hold commitment button.
    static let holdButtonHeight: CGFloat = 56

    /// The outline of a prominent control drawn on a tinted fill, so its
    /// edge holds against a black background.
    static let prominentBorderWidth: CGFloat = 1.5

    /// The height of an empty state's illustrative chart.
    static let emptyStateChartHeight: CGFloat = 96

    /// The widest an empty state's illustration grows, so it stays a
    /// hint rather than a screen-filling graphic on large displays.
    static let emptyStateIllustrationMaxWidth: CGFloat = 320

    // MARK: - Charts

    /// How far into a ring chart its hole reaches, as a share of radius.
    static let ringChartInnerRadiusRatio: CGFloat = 0.62

    /// The gap between neighboring sectors of a ring chart, in points.
    static let ringChartSectorInset: CGFloat = 1.5

    /// How much of its row a horizontal bar fills, leaving room for the
    /// name above it.
    static let barChartBarHeightRatio: CGFloat = 0.45

    /// The widest a ring chart grows, so it stays a glanceable figure on
    /// iPad and in landscape rather than filling the screen.
    static let ringChartMaxDiameter: CGFloat = 280
}
