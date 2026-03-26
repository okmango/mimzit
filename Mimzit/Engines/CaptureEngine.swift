import AVFoundation
import CoreMedia

/// Manages the AVCaptureSession lifecycle for live camera preview and recording.
///
/// ## Architecture
/// All session mutations are dispatched to a dedicated serial queue (`sessionQueue`)
/// to avoid blocking the main thread. Preview layer and recording state are
/// published back to the main actor for SwiftUI observation.
///
/// ## FOUND-02 Compliance
/// `captureSession.automaticallyConfiguresApplicationAudioSession = false` is set
/// inside `beginConfiguration()` — BEFORE any inputs are added. This prevents
/// AVCaptureSession from silently overriding the .playAndRecord audio category
/// that AudioSessionManager configures at app launch.
///
/// ## Audio Session
/// AudioSessionManager configures .playAndRecord mode at app launch (FOUND-01).
/// CaptureEngine does NOT reconfigure the audio session — it only disables the
/// AVCaptureSession auto-reconfiguration that would override it.
@Observable
@MainActor
final class CaptureEngine: NSObject {

    // MARK: - Session

    private let captureSession = AVCaptureSession()

    /// Dedicated serial queue for all session mutations (Apple-recommended pattern).
    /// Prevents blocking main thread during session start/stop/configure.
    private let sessionQueue = DispatchQueue(label: "com.mimzit.capture", qos: .userInitiated)

    // MARK: - Outputs

    private var movieOutput = AVCaptureMovieFileOutput()

    // MARK: - Published State

    /// The preview layer to embed in CompositorView. Available after `configure()`.
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    /// True while the capture session is actively running.
    private(set) var isSessionRunning = false

    /// The URL of the most recently completed recording.
    private(set) var lastRecordingURL: URL?

    // MARK: - Configuration

    /// Configures the capture session: adds front camera + mic inputs, movie file output,
    /// and creates the preview layer. Must be called once before `startSession()`.
    ///
    /// Dispatched to `sessionQueue` to avoid blocking the main thread.
    func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()

            // FOUND-02 (D-16): Must be set inside beginConfiguration(), before adding inputs.
            // Prevents AVCaptureSession from overriding .playAndRecord audio category.
            self.captureSession.automaticallyConfiguresApplicationAudioSession = false

            self.captureSession.sessionPreset = .high

            // Front camera input
            if let frontCamera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front
            ),
            let videoInput = try? AVCaptureDeviceInput(device: frontCamera),
            self.captureSession.canAddInput(videoInput) {
                self.captureSession.addInput(videoInput)
            }

            // Microphone input
            if let microphone = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: microphone),
               self.captureSession.canAddInput(audioInput) {
                self.captureSession.addInput(audioInput)
            }

            // Movie file output
            if self.captureSession.canAddOutput(self.movieOutput) {
                self.captureSession.addOutput(self.movieOutput)
            }

            self.captureSession.commitConfiguration()

            // Set video connection portrait orientation (iOS 17+ API)
            if let videoConnection = self.movieOutput.connection(with: .video) {
                if videoConnection.isVideoRotationAngleSupported(90) {
                    videoConnection.videoRotationAngle = 90
                }
            }

            // Create preview layer on MainActor — exposes session to CompositorView
            let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            layer.videoGravity = .resizeAspectFill
            // Note: Do NOT disable mirroring — front camera default mirroring is correct (Pitfall 4)

            Task { @MainActor [weak self] in
                self?.previewLayer = layer
            }
        }

        // Subscribe to session interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
    }

    // MARK: - Session Lifecycle

    /// Starts the capture session on the session queue.
    /// Updates `isSessionRunning` on the main actor when running.
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.startRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = true
            }
        }
    }

    /// Stops the capture session on the session queue.
    /// Updates `isSessionRunning` on the main actor when stopped.
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.stopRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = false
            }
        }
    }

    // MARK: - Recording

    /// Starts recording to the given URL.
    ///
    /// Guards `captureSession.isRunning` before calling startRecording (Pitfall 2 prevention).
    /// The delegate receives recording completion/error callbacks.
    ///
    /// - Parameters:
    ///   - url: Destination file URL (typically from FileVault.recordingURL)
    ///   - delegate: Receives `AVCaptureFileOutputRecordingDelegate` callbacks
    func startRecording(to url: URL, delegate: AVCaptureFileOutputRecordingDelegate) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.captureSession.isRunning else {
                return
            }
            self.movieOutput.startRecording(to: url, recordingDelegate: delegate)
        }
    }

    /// Stops an in-progress recording. The delegate's
    /// `fileOutput(_:didFinishRecordingTo:from:error:)` is called when complete.
    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
        }
    }

    // MARK: - Sync

    /// Returns the current host time for recording start synchronization (REC-05).
    ///
    /// Call immediately before `startRecording(to:delegate:)` to capture the precise
    /// timestamp. This value is stored with the session record in Phase 3 for
    /// accurate review playback alignment.
    func syncTimestamp() -> Double {
        CACurrentMediaTime()
    }

    // MARK: - Interruption Handlers

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.isSessionRunning = false
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isInterrupted == false else { return }
            self.captureSession.startRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = true
            }
        }
    }
}
