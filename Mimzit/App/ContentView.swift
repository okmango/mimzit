import SwiftUI

/// Root tab bar container for Mimzit.
///
/// ## Tab Structure (Phase 3)
/// - Library: Content library where users manage imported reference content
/// - Sessions: Session history for all past practice recordings
/// - Settings: API key configuration and app settings
struct ContentView: View {
    var body: some View {
        TabView {
            ContentLibraryView()
                .tabItem {
                    Label("Library", systemImage: "film.stack")
                }

            SessionHistoryView()
                .tabItem {
                    Label("Sessions", systemImage: "clock.arrow.circlepath")
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
        .modelContainer(for: [ReferenceContent.self, Session.self], inMemory: true)
}
