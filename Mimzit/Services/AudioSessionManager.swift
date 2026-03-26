import AVFoundation

/// Configures and monitors the app's AVAudioSession.
///
/// ## Why this matters (FOUND-01)
/// AVAudioSession.setCategory must be called BEFORE any AVPlayer or AVCaptureSession
/// is instantiated. This is called from MimzitApp.init() — the earliest possible point.
///
/// ## Category: .playAndRecord
/// The ONLY category that allows simultaneous mic input and audio output.
/// Required for recording the user while playing the reference audio.
///
/// ## Options explained
/// - `.allowBluetooth` / `.allowBluetoothHFP`: AirPods microphone input (HFP profile)
/// - `.allowBluetoothA2DP`: Higher-quality AirPods audio output (A2DP profile)
/// - `.defaultToSpeaker`: Reference audio plays through speaker/AirPods, not the earpiece
///
/// ## Mode: .videoRecording
/// Optimizes for video capture; suppresses noise cancellation that would hurt reference audio.
///
/// ## Phase 2 Note (FOUND-02)
/// When creating AVCaptureSession, set:
///   `captureSession.automaticallyConfiguresApplicationAudioSession = false`
/// This prevents AVCaptureSession from silently overriding the category we set here.
enum AudioSessionManager {

    /// Configure AVAudioSession in .playAndRecord mode.
    /// MUST be called before any AVPlayer or AVCaptureSession is created.
    /// Called from MimzitApp.init() — FOUND-01.
    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("AudioSession configuration failed: \(error)")
        }
    }

    /// Detects if headphones or AirPods are connected — FOUND-03.
    ///
    /// Checks current audio route outputs for headphone/Bluetooth port types.
    /// Returns `true` if wired headphones, AirPods, or any Bluetooth audio output is active.
    static var headphonesConnected: Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
                .contains(output.portType)
        }
    }

    /// Subscribes to audio route change notifications (AirPods connect/disconnect).
    ///
    /// The handler is called on the main queue when the audio route changes.
    /// Subscribe to this in Phase 2 when the recording engine is active to
    /// handle AirPods being connected or disconnected mid-session.
    static func observeRouteChanges(handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in handler() }
    }
}
