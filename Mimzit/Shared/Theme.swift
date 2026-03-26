import SwiftUI

/// App-wide color theme with semantic colors for Mimzit.
///
/// ## Design Philosophy
/// Mimzit is a focused professional tool for speech coaching.
/// Colors are minimal, purposeful, and fully adaptive to light/dark mode.
///
/// ## Usage
/// ```swift
/// .foregroundStyle(Theme.accent)
/// Image(systemName: "film").foregroundStyle(Theme.videoColor)
/// ```
enum Theme {
    /// Primary accent color — used for interactive CTAs, progress indicators, and active state.
    /// Light: #2E7DDE (R: 0.180, G: 0.490, B: 0.871)
    /// Dark:  #5AA0F5 (R: 0.353, G: 0.627, B: 0.961)
    static let accent = Color("AccentColor")

    // MARK: - Content Type Colors (fixed semantic, not adaptive)

    /// Video content type icon color — SF Symbol: film
    static let videoColor = Color(.systemBlue)

    /// Audio content type icon color — SF Symbol: waveform
    static let audioColor = Color(.systemPurple)

    /// Text/script content type icon color — SF Symbol: doc.text
    static let scriptColor = Color(.systemGreen)

    // MARK: - Status Colors

    /// Transcription complete status indicator
    static let transcriptReady = Color(.systemGreen)

    // MARK: - Recording UI Colors (Phase 2)

    /// Record button fill color when recording is active. Also used for the pulsing ring.
    static let recordActive = Color(.systemRed)

    /// Record button fill color when idle (not recording).
    static let recordIdle = Color.white.opacity(0.90)

    /// Pulsing outer ring color on the record button during active recording.
    static let recordPulse = Color(.systemRed).opacity(0.40)

    /// Fader track background color for both video and audio faders.
    static let faderTrack = Color.white.opacity(0.30)

    /// Fader filled-track color (the portion from the left edge to the thumb).
    static let faderFilled = Theme.accent.opacity(0.80)

    /// Bottom control panel background color (semi-transparent dark overlay).
    static let overlayPanel = Color.black.opacity(0.45)

    /// Semi-transparent background band behind transcript text in text overlay mode (VIEW-02).
    static let textOverlayBg = Color.black.opacity(0.55)

    /// Background for pill-shaped controls (fader panel, view mode pill).
    static let controlBg = Color.white.opacity(0.15)

    /// Dimmed text used for inactive/secondary labels over dark video backgrounds.
    static let dimmedText = Color.white.opacity(0.70)

    /// Non-current teleprompter line text color (D-14).
    static let teleprompterDim = Color.white.opacity(0.50)
}
