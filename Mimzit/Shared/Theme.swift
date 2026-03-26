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
}
