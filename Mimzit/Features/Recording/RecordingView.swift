import SwiftUI
import AVFoundation
import UIKit

/// Full-screen recording screen assembling all Phase 2 components.
///
/// ## Architecture
/// RecordingView owns a RecordingViewModel (created at init time from the content item).
/// The view composes four layers in a ZStack:
///   1. CompositorView (or TeleprompterView for text-only content) — fills screen
///   2. Text overlay band — conditional on .textOverlay mode
///   3. Control overlay (auto-hide) — ViewModeControl, timer, faders, record button
///
/// ## States
/// - Loading: session not yet running, shows "Preparing camera..." spinner
/// - Camera denied: permission denied, shows error card with Settings CTA
/// - Ready (idle): composer visible, controls visible, record button idle
/// - Recording: record button red + pulsing ring, timer showing, controls auto-hide
///
/// ## Navigation
/// Presented via `.fullScreenCover` from ContentDetailView — tab bar automatically hidden.
struct RecordingView: View {

    // MARK: - Properties

    let content: ReferenceContent

    @State private var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(content: ReferenceContent) {
        self.content = content
        self._viewModel = State(initialValue: RecordingViewModel(content: content))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // MARK: Layer 1: Video compositor or full-screen teleprompter
            if viewModel.isTextOnlyContent {
                TeleprompterView(
                    text: content.scriptText ?? "",
                    isScrolling: $viewModel.teleprompterScrolling,
                    scrollSpeed: $viewModel.scrollSpeed,
                    isFullScreen: true
                )
                .ignoresSafeArea()
            } else {
                CompositorView(
                    playerLayer: viewModel.playbackEngine.playerLayer,
                    previewLayer: viewModel.captureEngine.previewLayer,
                    videoBlend: effectiveVideoBlendBinding
                )
                .ignoresSafeArea()
            }

            // MARK: Layer 2: Text overlay band (video with transcript overlay mode)
            if viewModel.activeViewMode == .textOverlay
                && viewModel.hasTranscript
                && !viewModel.isTextOnlyContent {
                VStack {
                    Spacer()
                    TeleprompterView(
                        text: content.transcript ?? "",
                        isScrolling: $viewModel.teleprompterScrolling,
                        scrollSpeed: $viewModel.scrollSpeed,
                        isFullScreen: false
                    )
                    .frame(height: 180)
                    .opacity(Double(viewModel.textOverlayOpacity))
                }
                .ignoresSafeArea(edges: .bottom)
            }

            // MARK: Layer 3: Control overlay (auto-hide)
            controlOverlay
                .opacity(viewModel.controlsVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: viewModel.controlsVisible)

            // MARK: Loading state
            if !viewModel.captureEngine.isSessionRunning && !viewModel.cameraPermissionDenied && !viewModel.isTextOnlyContent {
                loadingView
            }

            // MARK: Camera denied state
            if viewModel.cameraPermissionDenied {
                cameraDeniedView
            }
        }
        .statusBarHidden(true)
        .onTapGesture {
            viewModel.showControls()
        }
        .task {
            await viewModel.setup()
        }
        .onDisappear {
            viewModel.teardown()
        }
        .onChange(of: viewModel.activeViewMode) { _, _ in
            viewModel.updateVideoBlendForMode()
        }
        .onChange(of: viewModel.audioBlend) { _, _ in
            viewModel.updateAudioBlend()
        }
        .onChange(of: viewModel.videoBlend) { _, _ in
            // Update textOverlayOpacity when in text overlay mode (D-11)
            if viewModel.activeViewMode == .textOverlay {
                viewModel.textOverlayOpacity = viewModel.videoBlend
            }
        }
    }

    // MARK: - Effective Video Blend Binding

    /// Binding that reads effectiveVideoBlend but writes to videoBlend.
    ///
    /// CompositorView receives the effective (mode-adjusted) blend for rendering,
    /// while the raw fader value is always written to videoBlend.
    private var effectiveVideoBlendBinding: Binding<Float> {
        Binding(
            get: { viewModel.effectiveVideoBlend },
            set: { viewModel.videoBlend = $0 }
        )
    }

    // MARK: - Control Overlay

    private var controlOverlay: some View {
        VStack(spacing: 0) {
            // Top: dismiss button + view mode pill
            HStack(alignment: .top) {
                dismissButton
                    .padding(.leading, 16)

                Spacer()
            }
            .padding(.top, 8)

            if !viewModel.isTextOnlyContent {
                ViewModeControl(
                    selected: $viewModel.activeViewMode,
                    hasTranscript: viewModel.hasTranscript
                )
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }

            // Center: recording timer
            if viewModel.isRecording {
                recordingTimerBadge
                    .padding(.top, 16)
            }

            Spacer()

            // Bottom panel: faders + record button
            bottomPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button {
            viewModel.teardown()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.45))
                .clipShape(Circle())
        }
        .accessibilityLabel("Dismiss recording")
    }

    // MARK: - Recording Timer Badge

    private var recordingTimerBadge: some View {
        VStack(spacing: 4) {
            Text("Recording")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.recordActive)
                .textCase(.uppercase)

            Text(viewModel.formattedDuration)
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // Video fader
            FaderView(
                value: $viewModel.videoBlend,
                trackHeight: 8,
                leftLabel: "REF",
                rightLabel: viewModel.activeViewMode.videoFaderRightLabel
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in viewModel.isFaderDragging = true }
                    .onEnded { _ in
                        viewModel.isFaderDragging = false
                        if viewModel.isRecording {
                            viewModel.showControls()
                        }
                    }
            )

            // Audio fader (hidden for text-only content)
            if viewModel.audioFaderVisible {
                FaderView(
                    value: $viewModel.audioBlend,
                    trackHeight: 4,
                    leftLabel: "REF",
                    rightLabel: "MIC"
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in viewModel.isFaderDragging = true }
                        .onEnded { _ in
                            viewModel.isFaderDragging = false
                            if viewModel.isRecording {
                                viewModel.showControls()
                            }
                        }
                )
            }

            // Speed control (text-only content only)
            if viewModel.isTextOnlyContent {
                HStack {
                    Text("Speed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.dimmedText)

                    Slider(value: $viewModel.scrollSpeed, in: 1...4, step: 0.5)
                        .tint(Theme.accent)

                    Text(String(format: "%.1fx", viewModel.scrollSpeed))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundColor(Theme.dimmedText)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            // Record button
            recordButton

            // Safe area spacer
            Spacer().frame(height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Theme.overlayPanel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        ZStack {
            // Pulsing ring (visible during recording)
            if viewModel.isRecording {
                Circle()
                    .stroke(Theme.recordPulse, lineWidth: 3)
                    .frame(width: 84, height: 84)
                    .scaleEffect(viewModel.isRecording ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: viewModel.isRecording
                    )
            }

            // Outer border ring
            Circle()
                .stroke(Color.white.opacity(0.30), lineWidth: 2)
                .frame(width: 72, height: 72)

            // Button body
            Button {
                viewModel.toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Theme.recordActive : Theme.recordIdle)
                        .frame(width: 72, height: 72)

                    if viewModel.isRecording {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    } else {
                        // Inner red dot for idle state
                        Circle()
                            .fill(Theme.recordActive)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .shadow(color: .black.opacity(0.50), radius: 8, y: 4)
            .accessibilityLabel(viewModel.isRecording ? "Stop Recording" : "Start Recording")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)

            Text("Preparing camera...")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.80))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.60))
    }

    // MARK: - Camera Denied View

    private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.70))

            VStack(spacing: 8) {
                Text("Camera Access Required")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text("Mimzit needs camera access to record your practice. Go to Settings to allow access.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            Button("Open iPhone Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
    }
}
