import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "NomadFi",
                systemImage: "globe",
                description: Text("Project scaffold ready for Phase 1 implementation.")
            )
            .navigationTitle("NomadFi")
        }
    }
}

#Preview {
    ContentView()
}
