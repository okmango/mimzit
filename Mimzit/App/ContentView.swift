import SwiftUI

/// Root tab bar container for Mimzit.
///
/// ## Tab Structure (Phase 1)
/// - Library: Content library where users manage imported reference content
/// - Settings: API key configuration and app settings
///
/// ## Phase 2
/// A Recording tab will be added between Library and Settings when the
/// camera + capture engine is built.
struct ContentView: View {
    var body: some View {
        TabView {
            // Placeholder — replaced with ContentLibraryView in Plan 02
            NavigationStack {
                Text("Library")
                    .navigationTitle("Library")
            }
            .tabItem {
                Label("Library", systemImage: "film.stack")
            }

            // Placeholder — replaced with SettingsView in Plan 02
            NavigationStack {
                Text("Settings")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }
}

#Preview {
    ContentView()
}
