import AVFoundation
import CoreMedia
import UIKit

/// Wraps AVPlayer with AVPlayerLayer for reference content playback.
///
/// ## Responsibilities
/// - Load a reference video or audio URL for playback
/// - Expose AVPlayerLayer for embedding in CompositorView (CALayer blend)
/// - Control playback volume for the audio fader (FADER-02)
/// - Auto-loop reference content when it reaches the end (Pitfall 5)
///
/// ## Volume Control
/// `volume` maps directly to `AVPlayer.volume` — the audio fader target.
/// Range: 0.0 (muted) to 1.0 (full). Default: 1.0 (reference audio fully audible).
///
/// ## End-of-Playback
/// Observes `AVPlayerItemDidPlayToEndTime` and calls `onFinished` when the
/// reference content reaches the end. Does NOT auto-loop — the recording
/// session should stop when the reference finishes.
@Observable
@MainActor
final class PlaybackEngine {

    // MARK: - Player

    private(set) var player = AVPlayer()

    /// The player layer for CompositorView. Set `playerLayer.frame` from the UIView layout pass.
    private(set) var playerLayer = AVPlayerLayer()

    // MARK: - State

    /// Audio fader target: 0.0 = muted, 1.0 = full reference audio. Updates AVPlayer.volume immediately.
    var volume: Float = 1.0 {
        didSet {
            player.volume = volume
        }
    }

    /// True while the player is actively playing.
    private(set) var isPlaying = false

    /// Called when the current item reaches the end. Set by RecordingViewModel
    /// to auto-stop recording when the reference finishes.
    var onFinished: (() -> Void)?

    // MARK: - End Observer

    private var endObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }

    nonisolated func cleanupObserver() {
        // Called explicitly before deallocation if needed.
        // deinit cannot access main actor properties in Swift 6.
    }

    // MARK: - Loading

    /// Loads a reference video or audio URL for playback.
    ///
    /// Sets `preferredMaximumResolution` to the screen's native size to prevent
    /// AVPlayer from loading a higher-resolution track than the display can show
    /// (Pitfall 6 prevention — avoids unnecessary decode overhead).
    ///
    /// - Parameter url: The absolute file URL (from FileVault.url(for:))
    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        // Prevent loading higher-res tracks than display can show (Pitfall 6)
        item.preferredMaximumResolution = UIScreen.main.nativeBounds.size
        player.replaceCurrentItem(with: item)
        setupEndObserver()
    }

    // MARK: - Playback Control

    /// Starts or resumes playback.
    func play() {
        player.play()
        isPlaying = true
    }

    /// Pauses playback without resetting position.
    func pause() {
        player.pause()
        isPlaying = false
    }

    /// Seeks to a specific time in the current item.
    /// - Parameter time: The target CMTime position
    func seek(to time: CMTime) {
        player.seek(to: time)
    }

    // MARK: - End-of-Playback

    /// Observes `AVPlayerItemDidPlayToEndTime` and fires `onFinished`.
    ///
    /// Does NOT auto-loop. When the reference finishes, playback stops and
    /// RecordingViewModel is notified to end the recording session.
    private func setupEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                self.onFinished?()
            }
        }
    }
}
