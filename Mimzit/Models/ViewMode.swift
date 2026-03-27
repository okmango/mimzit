/// The four recording view modes controlling which layers are visible.
///
/// ## D-10 Segment Labels
/// The raw value of each case is the segment label used in `ViewModeControl`:
/// Ref | Cam | Blend | Text
///
/// ## Layer Visibility
/// Each mode defines which CALayer sources are visible in the `CompositorView`:
/// - `showsReferenceLayer`: AVPlayerLayer (reference video/audio) is visible
/// - `showsCameraLayer`: AVCaptureVideoPreviewLayer (camera preview) is visible
/// - `showsTextOverlay`: TeleprompterView or transcript band overlay is visible
///
/// ## Fader Semantics (D-11)
/// In `.textOverlay` mode, the video fader controls text opacity instead of
/// the camera/reference blend. `faderControlsTextOpacity` signals this to the UI.
/// `videoFaderRightLabel` adapts the right-side fader anchor label accordingly.
enum ViewMode: String, CaseIterable {

    /// Reference-only: shows the reference video/audio layer only.
    case reference = "Ref"

    /// Camera-only: shows the user's live camera preview only.
    case camera = "Cam"

    /// Blended overlay: shows both reference and camera layers simultaneously.
    /// The video fader controls the blend ratio between the two.
    case blend = "Blend"

    /// Text overlay: shows the reference video with scrolling transcript on top.
    /// In text-only mode (ContentType == .text), shows full-screen teleprompter.
    /// The video fader controls text opacity instead of camera/reference blend (D-11).
    case textOverlay = "Text"

    // MARK: - Layer Visibility

    /// Whether the AVPlayerLayer (reference content) should be visible.
    /// True for all modes except `.camera`.
    var showsReferenceLayer: Bool {
        switch self {
        case .reference, .blend, .textOverlay: return true
        case .camera: return false
        }
    }

    /// Whether the AVCaptureVideoPreviewLayer (camera preview) should be visible.
    /// True only for `.camera` and `.blend` modes.
    var showsCameraLayer: Bool {
        switch self {
        case .camera, .blend: return true
        case .reference, .textOverlay: return false
        }
    }

    /// Whether the text overlay (transcript band or full teleprompter) should be visible.
    /// True only for `.textOverlay` mode.
    var showsTextOverlay: Bool {
        self == .textOverlay
    }

    // MARK: - Fader Semantics

    /// Whether the video fader controls text opacity instead of the camera blend ratio.
    /// True only for `.textOverlay` mode (D-11).
    var faderControlsTextOpacity: Bool {
        self == .textOverlay
    }

    /// The right-side anchor label for the video fader.
    /// Returns "TEXT" in textOverlay mode (the fader blends from no text to full text).
    /// Returns "CAM" for all other modes (fader blends from reference to camera).
    var videoFaderRightLabel: String {
        self == .textOverlay ? "TEXT" : "CAM"
    }

    // MARK: - Review Mode Labels (D-05, D-06)

    /// Segment label for review mode. "Cam" becomes "You" per D-05/D-06.
    var reviewSegmentLabel: String {
        switch self {
        case .reference: return "Ref"
        case .camera: return "You"
        case .blend: return "Blend"
        case .textOverlay: return "Text"
        }
    }

    /// Right-side fader label for review mode. "CAM" becomes "YOU" per D-05.
    var reviewVideoFaderRightLabel: String {
        self == .textOverlay ? "TEXT" : "YOU"
    }
}
