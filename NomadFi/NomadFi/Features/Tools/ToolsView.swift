// ToolsView.swift
// NomadFi
//
// The Tools tab: NomadFi's optional manual workflows, one tap each.

import SwiftUI

/// The root of the Tools tab: a grid of tool cards. Each tool relies
/// on this tab's `NavigationStack` for its own pushes and sheets.
struct ToolsView: View {

    var body: some View {
        ScrollView {
            TileGrid(items: Tool.allCases)
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
