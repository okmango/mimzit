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
            ContentLibraryView()
                .tabItem {
                    Label("Library", systemImage: "film.stack")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ReferenceContent.self, inMemory: true)
}
