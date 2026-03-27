import SwiftUI
import AVFoundation

/// UIViewRepresentable that stacks two AVPlayerLayers for the review playback screen.
///
/// ## Architecture
/// ReviewCompositorView owns no player logic — it bridges two CALayers (reference + user
/// recording) into SwiftUI for the review screen's fader blend. This is a dedicated type
/// (not a reuse of CompositorView) to keep the recording compositor unchanged (research Option A).
///
/// ## Layer Order
/// - referencePlayerLayer: bottom layer (reference video)
/// - userPlayerLayer: top layer (user recording)
///
/// ## Opacity Control
/// All frame and opacity updates are wrapped in CATransaction with setDisableActions(true)
/// to prevent implicit CALayer animations during fader drags (Pitfall 3).
///
/// ## ViewMode Behavior
/// - .reference: only reference layer visible
/// - .camera (maps to "You" in review): only user layer visible
/// - .blend: both visible, userPlayerLayer opacity = videoBlend
/// - .textOverlay: only reference layer visible (transcript band shown by parent)
struct ReviewCompositorView: UIViewRepresentable {

    // MARK: - Parameters

    /// AVPlayerLayer from the reference PlaybackEngine. Placed as the bottom sublayer.
    let referencePlayerLayer: AVPlayerLayer

    /// AVPlayerLayer from the user-recording PlaybackEngine. Placed as the top sublayer.
    let userPlayerLayer: AVPlayerLayer

    /// Fader position: 0.0 = reference only, 1.0 = user only.
    /// Only used in `.blend` mode — other modes lock layer opacity via `activeViewMode`.
    let videoBlend: Float

    /// The current view mode — drives which layers are visible.
    let activeViewMode: ViewMode

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        referencePlayerLayer.videoGravity = .resizeAspectFill
        userPlayerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(referencePlayerLayer)
        view.layer.addSublayer(userPlayerLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Wrap all frame and opacity mutations in a no-animation transaction (Pitfall 3).
        // Prevents implicit CALayer animations during fader drags and SwiftUI re-renders.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        referencePlayerLayer.frame = uiView.bounds
        userPlayerLayer.frame = uiView.bounds

        switch activeViewMode {
        case .reference:
            referencePlayerLayer.opacity = 1.0
            userPlayerLayer.opacity = 0.0
        case .camera:  // "You" mode in review context
            referencePlayerLayer.opacity = 0.0
            userPlayerLayer.opacity = 1.0
        case .blend:
            referencePlayerLayer.opacity = 1.0
            userPlayerLayer.opacity = videoBlend
        case .textOverlay:
            referencePlayerLayer.opacity = 1.0
            userPlayerLayer.opacity = 0.0
        }

        CATransaction.commit()
    }
}
