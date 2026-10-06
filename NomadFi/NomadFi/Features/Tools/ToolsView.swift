// ToolsView.swift
// NomadFi
//
// The Tools tab: NomadFi's optional manual workflows, one tap each.

import SwiftUI

/// The root of the Tools tab: a grid of tool cards.
///
/// Two columns, or one at accessibility text sizes so titles never
/// truncate. A `Grid` rather than a lazy grid: with a handful of tools
/// nothing needs to load lazily, and a `Grid` gives every card in a row
/// the row's height. Each tool relies on this tab's `NavigationStack`
/// for its own pushes and sheets.
struct ToolsView: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: SpacingTokens.small, verticalSpacing: SpacingTokens.small) {
                ForEach(Tool.rows(columns: dynamicTypeSize.isAccessibilitySize ? 1 : 2), id: \.self) { row in
                    GridRow {
                        ForEach(row) { tool in
                            NavigationLink(value: tool) {
                                ToolCard(tool: tool)
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }
            .padding(SpacingTokens.medium)
        }
        .navigationTitle("Tools")
        .navigationDestination(for: Tool.self) { tool in
            ToolDestination(tool: tool)
        }
    }
}

#Preview {
    NavigationStack {
        ToolsView()
    }
}
