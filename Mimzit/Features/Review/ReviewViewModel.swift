import Foundation
import AVFoundation
import SwiftUI

/// ViewModel for the review playback screen.
///
/// ## Architecture
/// ReviewViewModel owns two PlaybackEngine instances — one for the reference content
/// and one for the user's recorded session — and keeps them synchronized during playback.
///
/// ## Sync Strategy
/// A periodic time observer on the reference player fires every 100ms. If the user
/// player drifts more than 50ms (REV-02), it is seeked to match the reference time.
/// Both players start from t=0 (see setup() inline comments for syncTimestamp rationale).
///
/// ## Audio Blend (D-07)
/// audioBlend: 0.0 = reference audio only, 1.0 = user audio only.
/// updateAudioBlend() applies this to each engine's volume property.
@Observable
@MainActor
final class ReviewViewModel {

    // MARK: - Injected Dependencies

    let session: Session
    let referenceContent: ReferenceContent

    // MARK: - Engines

    let referenceEngine = PlaybackEngine()
    let userEngine = PlaybackEngine()

    // MARK: - UI State

    var videoBlend: Float = 0.5
    var audioBlend: Float = 0.0
    var activeViewMode: ViewMode = .blend
    var isPlaying = false
    var scrubPosition: Double = 0  // 0.0-1.0 normalized
    var duration: TimeInterval = 0
    var currentTimeString: String = "00:00"
    var durationString: String = "00:00"

    // MARK: - Sync

    private var syncObserver: Any?
    private let syncThreshold: Double = 0.05  // 50ms tolerance (REV-02)

    // MARK: - Computed Properties

    var hasTranscript: Bool {
        referenceContent.transcript != nil && !(referenceContent.transcript?.isEmpty ?? true)
    }

    // MARK: - Init

    init(session: Session, referenceContent: ReferenceContent) {
        self.session = session
        self.referenceContent = referenceContent
    }

    // MARK: - Setup

    func setup() {
        // Load reference content
        if let filename = referenceContent.filename {
            let refURL = FileVault.url(for: filename)
            referenceEngine.load(url: refURL)
        }
        // Load user recording
        let userURL = FileVault.sessionURL(for: session.recordingFilename)
        userEngine.load(url: userURL)

        // Use the shorter of reference and user recording as the scrub bar duration.
        // If the user recorded less than the full reference, the scrub bar should
        // only extend to the end of the shorter track so the timeline is accurate.
        let referenceDuration = referenceContent.duration ?? session.duration
        duration = min(referenceDuration, session.duration)
        durationString = formatTime(duration)

        // Apply syncTimestamp alignment (per D-13, REV-02).
        // Current recording flow: RecordingViewModel seeks reference to .zero before
        // starting capture, so both tracks genuinely start at t=0. The syncTimestamp
        // stored on Session is the CACurrentMediaTime() host-clock value at recording
        // start -- it is NOT a media offset. Therefore both players start at .zero.
        //
        // This defensive seek ensures correct alignment even if the recording flow
        // changes in the future (e.g., recording starts mid-reference). If syncTimestamp
        // were repurposed as a media offset, this is where the offset would be applied:
        //   let offset = CMTime(seconds: session.syncTimestamp, preferredTimescale: 600)
        //   referenceEngine.seek(to: offset)
        // For now, both seek to .zero to guarantee alignment.
        referenceEngine.seek(to: .zero)
        userEngine.seek(to: .zero)

        // Shared reset: pause both engines and return to start.
        // Extracted as a local closure so both onFinished handlers share identical behaviour.
        let resetPlayback: @Sendable () -> Void = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.referenceEngine.pause()
                self.userEngine.pause()
                self.isPlaying = false
                self.referenceEngine.seek(to: .zero)
                self.userEngine.seek(to: .zero)
                self.scrubPosition = 0
                self.currentTimeString = "00:00"
            }
        }

        // Either video reaching its end stops both and resets to start.
        // This handles the case where the user recording is shorter than the reference:
        // when userEngine fires onFinished the reference is paused immediately.
        referenceEngine.onFinished = resetPlayback
        userEngine.onFinished = resetPlayback

        setupSyncObserver()
        updateAudioBlend()
    }

    // MARK: - Sync Observer

    private func setupSyncObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        syncObserver = referenceEngine.player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                // Update scrub position
                if self.duration > 0 {
                    self.scrubPosition = time.seconds / self.duration
                }
                self.currentTimeString = self.formatTime(time.seconds)

                // Drift correction (REV-02): if user player drifts > 50ms, resync
                let refTime = time.seconds
                let userTime = self.userEngine.player.currentTime().seconds
                let drift = abs(refTime - userTime)
                if drift > self.syncThreshold {
                    self.userEngine.seek(to: CMTime(seconds: refTime, preferredTimescale: 600))
                }
            }
        }
    }

    // MARK: - Playback Control

    func togglePlayPause() {
        if isPlaying {
            referenceEngine.pause()
            userEngine.pause()
            isPlaying = false
        } else {
            referenceEngine.play()
            userEngine.play()
            isPlaying = true
        }
    }

    func scrub(to normalizedPosition: Double) {
        let targetSeconds = normalizedPosition * duration
        let target = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        referenceEngine.seek(to: target)
        userEngine.seek(to: target)
        currentTimeString = formatTime(targetSeconds)
    }

    // MARK: - Audio Blend

    func updateAudioBlend() {
        // audioBlend: 0.0 = reference only, 1.0 = user only (per D-07)
        referenceEngine.volume = 1.0 - audioBlend
        userEngine.volume = audioBlend
    }

    // MARK: - Teardown

    func teardown() {
        if let obs = syncObserver {
            referenceEngine.player.removeTimeObserver(obs)
            syncObserver = nil
        }
        referenceEngine.pause()
        userEngine.pause()
    }

    // MARK: - Time Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
