import SwiftUI
import AVFoundation

/// UIViewRepresentable that stacks AVPlayerLayer (bottom) and AVCaptureVideoPreviewLayer (top)
/// as CALayer sublayers for the live fader blend on the recording screen.
///
/// ## Architecture
/// CompositorView owns no player or capture logic — it simply bridges two CALayers into SwiftUI.
/// Layer opacity is driven by the `videoBlend` binding (0.0 = reference only, 1.0 = camera only).
/// All frame and opacity updates are wrapped in `CATransaction` with `setDisableActions(true)`
/// to prevent implicit CALayer animations that would cause a visible lag on fader drags (Pitfall 3).
///
/// ## Usage
/// ```swift
/// CompositorView(
///     playerLayer: playbackEngine.playerLayer,
///     previewLayer: captureEngine.previewLayer,
///     videoBlend: $videoBlend
/// )
/// .ignoresSafeArea()
/// ```
struct CompositorView: UIViewRepresentable {

    // MARK: - Parameters

    /// The AVPlayerLayer from PlaybackEngine. Placed as the bottom sublayer.
    let playerLayer: AVPlayerLayer

    /// The AVCaptureVideoPreviewLayer from CaptureEngine. Placed as the top sublayer.
    /// Optional because CaptureEngine configures it asynchronously after `configure()` is called.
    let previewLayer: AVCaptureVideoPreviewLayer?

    /// Fader position: 0.0 = reference only (previewLayer invisible), 1.0 = camera only.
    /// Drives `previewLayer.opacity` — GPU-composited by the system at zero CPU cost (FADER-04).
    @Binding var videoBlend: Float

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        // Add playerLayer (reference video — bottom sublayer)
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)

        // Add previewLayer if already available (camera may not be ready on first render)
        if let previewLayer {
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Wrap all frame and opacity mutations in a no-animation transaction (Pitfall 3).
        // Prevents implicit CALayer animations during fader drags and SwiftUI re-renders.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        playerLayer.frame = uiView.bounds

        if let previewLayer {
            // Handle late initialization: add previewLayer if it hasn't been added yet.
            if previewLayer.superlayer == nil {
                previewLayer.videoGravity = .resizeAspectFill
                uiView.layer.addSublayer(previewLayer)
            }
            previewLayer.frame = uiView.bounds
            // Fader blend: previewLayer opacity tracks videoBlend (0 = hidden, 1 = opaque)
            previewLayer.opacity = videoBlend
        }

        CATransaction.commit()
    }
}
