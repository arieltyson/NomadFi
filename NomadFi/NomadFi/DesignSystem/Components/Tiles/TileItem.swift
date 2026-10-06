// TileItem.swift
// NomadFi
//
// What a destination needs to appear as a tinted card in a TileGrid.

import SwiftUI

/// A destination shown as a tinted card: a symbol in its colour above
/// its title. Tools and Financial Setup both conform, so their cards
/// are the same component.
protocol TileItem: Identifiable, Hashable {

    var title: LocalizedStringKey { get }
    var systemImage: String { get }

    /// Each item's own hue; every other property of the card comes
    /// from the design system, so a grid reads as one family.
    var tint: Color { get }
}

/// How a grid of tiles breaks into rows.
enum TileLayout {

    /// `items` in rows of `columns`, in order.
    static func rows<Item>(_ items: [Item], columns: Int) -> [[Item]] {
        let columns = max(columns, 1)
        return stride(from: 0, to: items.count, by: columns).map { start in
            Array(items[start..<min(start + columns, items.count)])
        }
    }
}
