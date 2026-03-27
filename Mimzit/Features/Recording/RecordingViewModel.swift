import AVFoundation
import CoreMedia
import SwiftUI

/// Session coordinator that owns CaptureEngine + PlaybackEngine and manages all recording state.
///
/// ## Responsibilities
/// - Camera/microphone permission flow
/// - Starting and stopping recording (via CaptureEngine)
/// - Starting and stopping reference playback (via PlaybackEngine)
/// - Video fader blend (0.0 = reference only, 1.0 = camera only)
/// - Audio fader blend (0.0 = full reference audio, 1.0 = muted reference)
/// - View mode switching and layer visibility
/// - Auto-hide controls after 3 seconds during recording (D-04)
/// - Teleprompter scroll start/stop (D-13)
/// - Recording duration timer
/// - AVCaptureFileOutputRecordingDelegate callbacks
///
/// ## Design
/// @Observable @MainActor — all state mutations happen on main actor.
/// Engines are owned by the view model; passed as references to the view.
@Observable
@MainActor
final class RecordingViewModel: NSObject, AVCaptureFileOutputRecordingDelegate {

    // MARK: - Injected Content

    /// The reference content item being practiced against.
    let content: ReferenceContent

    // MARK: - Engines

    /// Manages AVCaptureSession lifecycle: preview layer and file recording.
    let captureEngine = CaptureEngine()

    /// Manages AVPlayer and AVPlayerLayer for reference video/audio playback.
    let playbackEngine = PlaybackEngine()

    // MARK: - Recording State

    /// True while AVCaptureMovieFileOutput is actively recording.
    var isRecording = false

    /// Video fader position: 0.0 = reference only, 1.0 = camera only. (D-08 default: 0.5)
    var videoBlend: Float = 0.5

    /// Audio fader position: 0.0 = full reference volume, 1.0 = muted reference. (D-08 default: 0.0)
    var audioBlend: Float = 0.0

    /// The currently selected view mode. (D-10 default: .blend)
    var activeViewMode: ViewMode = .blend

    // MARK: - UI State

    /// Whether the control overlay is currently visible. Drives animation in RecordingView.
    var controlsVisible = true

    /// True while the user is actively dragging a fader — suppresses auto-hide (D-04).
    var isFaderDragging = false

    // MARK: - Sync

    /// Host time captured immediately before startRecording is called (REC-05).
    /// Stored with the session in Phase 3 for review playback offset calculation.
    var syncTimestamp: Double = 0

    /// The URL of the most recently completed recording file.
    var lastRecordingURL: URL?

    // MARK: - Teleprompter

    /// Driven by isRecording — scroll starts when recording starts, stops when recording stops (D-13).
    var teleprompterScrolling = false

    /// Teleprompter speed multiplier (1.0–4.0). Default 1.0.
    var scrollSpeed: Double = 1.0

    /// Text overlay opacity in .textOverlay mode — controlled by the video fader (D-11).
    var textOverlayOpacity: Float = 1.0

    // MARK: - Duration Timer

    /// Elapsed recording time in seconds. Resets to 0 at each recording start.
    var recordingDuration: TimeInterval = 0

    // MARK: - Save Confirmation

    /// True while the "Session Saved" toast banner is visible (D-02).
    var showSavedBanner = false

    // MARK: - Permission

    /// True if the user has denied camera or microphone access.
    var cameraPermissionDenied = false

    // MARK: - Private Tasks

    private var controlsHideTask: Task<Void, Never>?
    private var durationTimer: Task<Void, Never>?

    // MARK: - Init

    init(content: ReferenceContent) {
        self.content = content
        super.init()
    }

    // MARK: - Computed Properties

    /// True when content has a Whisper transcript available. Gates the "Text" segment in ViewModeControl.
    var hasTranscript: Bool {
        content.transcript != nil
    }

    /// True when content type is .text — shows full-screen teleprompter instead of video compositor.
    var isTextOnlyContent: Bool {
        content.contentType == .text
    }

    /// Whether the audio fader is visible. Hidden for text-only content (no audio to blend).
    var audioFaderVisible: Bool {
        content.contentType != .text
    }

    /// Recording duration formatted as "MM:SS".
    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Setup / Teardown

    /// Requests permissions, configures engines, and loads reference content.
    ///
    /// Call via `.task { await viewModel.setup() }` in RecordingView.
    func setup() async {
        // Camera permission
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if videoStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                cameraPermissionDenied = true
                return
            }
        } else if videoStatus == .denied || videoStatus == .restricted {
            cameraPermissionDenied = true
            return
        }

        // Microphone permission
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                cameraPermissionDenied = true
                return
            }
        } else if audioStatus == .denied || audioStatus == .restricted {
            cameraPermissionDenied = true
            return
        }

        // Configure and start capture session
        captureEngine.configure()
        captureEngine.startSession()

        // Load reference content for playback (video and audio content types)
        if let filename = content.filename {
            let url = FileVault.url(for: filename)
            playbackEngine.load(url: url)
        }

        // Set initial volume: audioBlend 0.0 = full reference volume
        playbackEngine.volume = 1.0

        // Auto-stop recording when reference content finishes
        playbackEngine.onFinished = { [weak self] in
            guard let self, self.isRecording else { return }
            self.toggleRecording()
        }

        // Clean up any recording temp files older than 24 hours
        FileVault.cleanupOldRecordings()
    }

    /// Stops all engines and cancels in-flight tasks.
    ///
    /// Call from `.onDisappear` in RecordingView.
    func teardown() {
        captureEngine.stopSession()
        playbackEngine.pause()
        controlsHideTask?.cancel()
        durationTimer?.cancel()
    }

    // MARK: - Recording Control

    /// Starts or stops recording depending on current state.
    ///
    /// Start: captures sync timestamp, starts AVCaptureMovieFileOutput recording,
    /// seeks reference to zero and plays it, starts duration timer, schedules auto-hide.
    ///
    /// Stop: stops AVCaptureMovieFileOutput recording, pauses reference, cancels timer.
    func toggleRecording() {
        if !isRecording {
            // REC-05: capture host time immediately before async recording start
            syncTimestamp = captureEngine.syncTimestamp()

            let filename = "\(UUID().uuidString).mov"
            let outputURL = FileVault.recordingURL(filename: filename)
            captureEngine.startRecording(to: outputURL, delegate: self)

            // Lock reference audio to full volume during recording
            playbackEngine.volume = 1.0

            // Sync reference playback with recording start
            if content.contentType == .video || content.contentType == .audio {
                playbackEngine.seek(to: .zero)
                playbackEngine.play()
            }

            isRecording = true
            teleprompterScrolling = true
            recordingDuration = 0

            // Start 1-second elapsed timer
            durationTimer = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled {
                        recordingDuration += 1
                    }
                }
            }

            scheduleControlsHide()

        } else {
            captureEngine.stopRecording()
            playbackEngine.pause()
            isRecording = false
            teleprompterScrolling = false
            // Restore audio fader control now that recording stopped
            updateAudioBlend()
            durationTimer?.cancel()
            controlsHideTask?.cancel()
            withAnimation(.easeIn(duration: 0.2)) {
                controlsVisible = true
            }
        }
    }

    // MARK: - Fader Updates

    /// Syncs PlaybackEngine volume with the audio fader position.
    ///
    /// During recording: always full reference volume (1.0) regardless of fader.
    /// During review/idle: audioBlend 0.0 = full reference (volume 1.0),
    /// audioBlend 1.0 = muted reference (volume 0.0). (FADER-02)
    func updateAudioBlend() {
        if isRecording {
            playbackEngine.volume = 1.0
        } else {
            playbackEngine.volume = 1.0 - audioBlend
        }
    }

    /// Adjusts layer visibility and effective blend when the view mode changes.
    ///
    /// Called from `.onChange(of: viewModel.activeViewMode)` in RecordingView.
    func updateVideoBlendForMode() {
        switch activeViewMode {
        case .reference:
            // Lock compositor to reference only
            videoBlend = 0.0
        case .camera:
            // Lock compositor to camera only
            videoBlend = 1.0
        case .blend:
            // Fader controls blend — no override, use current videoBlend value
            break
        case .textOverlay:
            // Fader controls text opacity (D-11); effectiveVideoBlend returns 0.0
            textOverlayOpacity = videoBlend
        }
    }

    // MARK: - Controls Auto-Hide (D-04, Pattern 7)

    /// Schedules the control overlay to hide after 3 seconds.
    ///
    /// Cancelled and rescheduled on any user interaction.
    /// Does not hide while isFaderDragging is true.
    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !isFaderDragging else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                controlsVisible = false
            }
        }
    }

    /// Shows the control overlay and reschedules auto-hide if recording is active.
    ///
    /// Call from tap gesture on the compositor area.
    func showControls() {
        withAnimation(.easeIn(duration: 0.2)) {
            controlsVisible = true
        }
        if isRecording {
            scheduleControlsHide()
        }
    }

    // MARK: - Save Confirmation Banner (D-02)

    /// Briefly shows the "Session Saved" toast banner for 2 seconds, then hides it.
    ///
    /// Call after a session has been successfully persisted to SwiftData.
    func showSaveConfirmation() {
        withAnimation(.easeIn(duration: 0.2)) {
            showSavedBanner = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) {
                showSavedBanner = false
            }
        }
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    /// Called when recording successfully starts. Updates isRecording on main actor.
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            self.isRecording = true
        }
    }

    /// Called when recording finishes (success or error). Stores recording URL.
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.lastRecordingURL = outputFileURL
            // If error interrupted recording externally, ensure state is consistent
            if self.isRecording {
                self.isRecording = false
            }
        }
    }
}
