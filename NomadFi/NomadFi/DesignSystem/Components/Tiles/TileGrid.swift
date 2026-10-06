// TileGrid.swift
// NomadFi
//
// A grid of tinted cards, each opening its item.

import SwiftUI

/// Tiles in two columns — one at accessibility text sizes, so titles
/// never truncate. A `Grid` rather than a lazy grid: there are only a
/// handful of tiles, and a `Grid` gives every card in a row the row's
/// height.
///
/// Two ways to open a tile:
/// - `TileGrid(items:)` pushes each item as a navigation value, for a
///   grid in a scroll view; the screen registers
///   `navigationDestination(for: Item.self)`. Destinations that push
///   their own values (Tax Vault, Ledger, Investing Learn) need this.
/// - `TileGrid(items:onSelect:)` makes tiles buttons, for a grid inside
///   a `List` row, which would otherwise turn every link in the row
///   into one navigation row.
struct TileGrid<Item: TileItem>: View {

    let items: [Item]
    private let onSelect: ((Item) -> Void)?

    /// Tiles push their item as a navigation value.
    init(items: [Item]) {
        self.items = items
        self.onSelect = nil
    }

    /// Tiles call `onSelect` with their item.
    init(items: [Item], onSelect: @escaping (Item) -> Void) {
        self.items = items
        self.onSelect = onSelect
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Grid(horizontalSpacing: SpacingTokens.small, verticalSpacing: SpacingTokens.small) {
            ForEach(TileLayout.rows(items, columns: dynamicTypeSize.isAccessibilitySize ? 1 : 2), id: \.self) { row in
                GridRow {
                    ForEach(row) { item in
                        if let onSelect {
                            Button {
                                onSelect(item)
                            } label: {
                                TileCard(item: item)
                            }
                            .buttonStyle(.card)
                        } else {
                            NavigationLink(value: item) {
                                TileCard(item: item)
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }
        }
    }
}
