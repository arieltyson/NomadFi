// ToolsView.swift
// NomadFi
//
// The Tools tab: Decisions and NomadFi's optional manual workflows,
// one tap each.

import SwiftUI

/// The root of the Tools tab: a grid of tool cards in the tab's own
/// navigation stack. Each tool relies on this stack for its pushes
/// and sheets.
///
/// Owning the path lets a launch route open a tool directly: an App
/// Intent writes the tool's raw value to ``Tool/pendingStorageKey``
/// and this view replaces the stack with that tool, then clears the
/// request so it fires once.
struct ToolsView: View {

    @State private var path: [Tool] = []

    @AppStorage(Tool.pendingStorageKey, store: AppRoutingDefaults.shared)
    private var pendingTool: String = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                TileGrid(items: Tool.allCases)
                    .padding(SpacingTokens.medium)
            }
            .navigationTitle("Tools")
            .navigationDestination(for: Tool.self) { tool in
                ToolDestination(tool: tool)
            }
        }
        .onChange(of: pendingTool, initial: true) { _, rawValue in
            guard let tool = Tool(rawValue: rawValue) else { return }
            path = [tool]
            pendingTool = ""
        }
    }
}

#Preview {
    ToolsView()
}
