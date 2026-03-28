import SwiftUI
import SwiftData
import AVFoundation

/// Full-screen review playback screen for a saved practice session.
///
/// ## Architecture
/// ReviewView owns a ReviewViewModel (created asynchronously after fetching ReferenceContent
/// from SwiftData by session.referenceContentID). The view assembles:
///   1. ReviewCompositorView (two AVPlayerLayers — reference + user recording)
///   2. Text overlay band (conditional on .textOverlay mode with transcript)
///   3. Control overlay (dismiss, ViewModeControl, scrub bar, faders, play/pause)
///
/// ## Navigation
/// Presented via NavigationLink from SessionHistoryView session rows.
///
/// ## Differences from RecordingView
/// - ReviewCompositorView instead of CompositorView (no camera layer)
/// - Play/pause button instead of record button
/// - Scrub bar (Slider) for timeline seeking (REV-03)
/// - Fader labels REF/YOU instead of REF/CAM (D-05)
/// - ViewModeControl with isReviewMode = true (shows "You" instead of "Cam", D-06)
struct ReviewView: View {

    // MARK: - Properties

    let session: Session

    @State private var viewModel: ReviewViewModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let viewModel {
                // Layer 1: Video compositor (two AVPlayerLayers)
                ReviewCompositorView(
                    referencePlayerLayer: viewModel.referenceEngine.playerLayer,
                    userPlayerLayer: viewModel.userEngine.playerLayer,
                    videoBlend: viewModel.videoBlend,
                    activeViewMode: viewModel.activeViewMode
                )
                .ignoresSafeArea()

                // Layer 2: Text overlay band (if transcript exists and in textOverlay mode)
                if viewModel.activeViewMode == .textOverlay && viewModel.hasTranscript {
                    VStack {
                        Spacer()
                        TeleprompterView(
                            text: viewModel.referenceContent.transcript ?? "",
                            isScrolling: .constant(false),
                            scrollSpeed: .constant(1.0),
                            isFullScreen: false
                        )
                        .frame(height: 180)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                // Layer 3: Control overlay
                reviewControlOverlay(viewModel: viewModel)

            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .statusBarHidden(true)
        .navigationBarHidden(true)
        .task {
            await setupViewModel()
        }
        .onDisappear {
            viewModel?.teardown()
        }
    }

    // MARK: - ViewModel Setup

    /// Fetches ReferenceContent by session.referenceContentID and initializes ReviewViewModel.
    private func setupViewModel() async {
        let contentID = session.referenceContentID
        let descriptor = FetchDescriptor<ReferenceContent>(
            predicate: #Predicate { $0.id == contentID }
        )
        guard let content = try? modelContext.fetch(descriptor).first else { return }
        let vm = ReviewViewModel(session: session, referenceContent: content)
        vm.setup()
        viewModel = vm
    }

    // MARK: - Control Overlay

    @ViewBuilder
    private func reviewControlOverlay(viewModel: ReviewViewModel) -> some View {
        VStack(spacing: 0) {
            // Top: dismiss button + session date label
            HStack {
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
                .padding(.leading, 16)

                Spacer()

                Text(session.recordedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.trailing, 16)
            }
            .padding(.top, 8)

            // View mode control (D-06: Ref | You | Blend, Text if transcript)
            ViewModeControl(
                selected: Binding(
                    get: { viewModel.activeViewMode },
                    set: { viewModel.activeViewMode = $0 }
                ),
                hasTranscript: viewModel.hasTranscript,
                isReviewMode: true
            )
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()

            // Bottom panel: scrub bar + faders + play/pause
            reviewBottomPanel(viewModel: viewModel)
        }
    }

    // MARK: - Bottom Panel

    @ViewBuilder
    private func reviewBottomPanel(viewModel: ReviewViewModel) -> some View {
        VStack(spacing: 12) {
            // Scrub bar (REV-03)
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { viewModel.scrubPosition },
                        set: { viewModel.scrub(to: $0) }
                    ),
                    in: 0...1
                )
                .tint(Theme.accent)

                HStack {
                    Text(viewModel.currentTimeString)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(Theme.dimmedText)
                    Spacer()
                    Text(viewModel.durationString)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(Theme.dimmedText)
                }
            }

            // Video fader (D-05: REF / YOU labels)
            FaderView(
                value: Binding(
                    get: { viewModel.videoBlend },
                    set: { viewModel.videoBlend = $0 }
                ),
                trackHeight: 8,
                leftLabel: "REF",
                rightLabel: viewModel.activeViewMode.reviewVideoFaderRightLabel
            )

            // Audio fader (D-05: REF / YOU, D-07: audioBlend 0.0 = ref only, 1.0 = user only)
            // Binding.set calls updateAudioBlend() directly — more reliable than onChange
            // with optional-chained expressions under @Observable.
            FaderView(
                value: Binding(
                    get: { viewModel.audioBlend },
                    set: {
                        viewModel.audioBlend = $0
                        viewModel.updateAudioBlend()
                    }
                ),
                trackHeight: 4,
                leftLabel: "REF",
                rightLabel: "YOU"
            )

            // Play/pause button (replaces record button per D-04)
            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 64, height: 64)
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: .black.opacity(0.50), radius: 8, y: 4)
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

            Spacer().frame(height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Theme.overlayPanel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
