import SwiftUI
import SwiftData

/// Main entry point for the Mimzit app.
///
/// ## Lifecycle
/// 1. AudioSession is configured FIRST — before any media engine (FOUND-01).
///    AVAudioSession.setCategory must be called before AVPlayer or AVCaptureSession is created.
/// 2. SwiftData ModelContainer is initialized with versioned migration support.
/// 3. ContentView is displayed as the root scene.
///
/// ## Critical: Audio Session Order
/// AudioSessionManager.configure() is intentionally called in init() before ModelContainer
/// to ensure .playAndRecord mode is active before any view lifecycle starts.
@main
struct MimzitApp: App {
    let container: ModelContainer

    init() {
        // 1. Audio session FIRST — before any media engine (FOUND-01)
        AudioSessionManager.configure()

        // 2. SwiftData container with migration plan
        do {
            container = try ModelContainer(
                for: Schema([ReferenceContent.self, Session.self]),
                migrationPlan: MimzitMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
