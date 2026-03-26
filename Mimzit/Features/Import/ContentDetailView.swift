import SwiftUI
import AVKit

/// Detail/preview sheet for a reference content item.
///
/// Per UI-SPEC Screen 2:
/// - Media preview (video thumbnail/player, audio waveform, text preview)
/// - Title and metadata (type, duration)
/// - Transcript section with live TranscriptionService integration (Plan 03)
/// - "Start Practice" button (disabled in Phase 1, wired in Phase 2)
///
/// Presented as a `.sheet` from ContentLibraryView list row tap.
struct ContentDetailView: View {
    let content: ReferenceContent
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isPlayingAudio = false

    // MARK: - Transcription State (Plan 03)
    @State private var transcriptionService = TranscriptionService()
    @State private var transcribeState: TranscribeState = .idle
    @State private var showAPIKeyPrompt = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Media preview
                    mediaPreview
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Title
                    Text(content.title)
                        .font(.headline)

                    // Metadata
                    HStack {
                        Text(typeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let duration = content.duration {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Transcript section
                    transcriptSection

                    Spacer(minLength: 24)

                    // Start Practice (disabled Phase 1, wired in Phase 2)
                    Button("Start Practice") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(true)
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .onAppear {
                if content.transcript != nil {
                    transcribeState = .complete
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
                isPlayingAudio = false
            }
            .sheet(isPresented: $showAPIKeyPrompt) {
                APIKeyPromptSheet(onSave: startTranscription)
            }
        }
    }

    // MARK: - Computed View Builders

    @ViewBuilder
    private var mediaPreview: some View {
        switch content.contentType {
        case .video:
            videoPreview
        case .audio:
            audioPreview
        case .text:
            textPreview
        }
    }

    @ViewBuilder
    private var videoPreview: some View {
        if let player {
            VideoPlayer(player: player)
        } else if let thumbFilename = content.thumbnailFilename,
                  FileVault.fileExists(thumbFilename),
                  let uiImage = UIImage(contentsOfFile: FileVault.url(for: thumbFilename).path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .contentShape(Rectangle())
                .onTapGesture { startVideoPlayback() }
                .overlay(alignment: .center) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                VStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("No preview available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { startVideoPlayback() }
        }
    }

    @ViewBuilder
    private var audioPreview: some View {
        ZStack {
            Theme.audioColor.opacity(0.15)
            VStack(spacing: 12) {
                Image(systemName: isPlayingAudio ? "pause.fill" : "waveform")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.audioColor)
                Text(isPlayingAudio ? "Playing" : "Tap to play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleAudioPlayback() }
    }

    @ViewBuilder
    private var textPreview: some View {
        if let text = content.scriptText, !text.isEmpty {
            Text(text)
                .font(.body)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "doc.text")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.scriptColor)
            }
        }
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if content.contentType != .text {
            TranscribeButtonView(state: transcribeState, onTranscribe: startTranscription)

            if let transcript = content.transcript {
                Text(transcript)
                    .font(.body)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Transcription

    private func startTranscription() {
        Task {
            transcribeState = .inProgress
            do {
                let text = try await transcriptionService.transcribe(content: content)
                content.transcript = text  // TRANS-03: save to SwiftData model
                transcribeState = .complete
            } catch let error as TranscriptionError {
                switch error {
                case .noAPIKey:
                    transcribeState = .idle
                    showAPIKeyPrompt = true
                case .noNetwork:
                    transcribeState = .error("Transcription failed. Check your connection and try again.")
                case .fileTooLarge:
                    transcribeState = .error("Audio is too long to transcribe. Try a shorter clip.")
                default:
                    transcribeState = .error(error.localizedDescription)
                }
            } catch {
                transcribeState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Playback Helpers

    private var typeLabel: String {
        switch content.contentType {
        case .video: return "Video"
        case .audio: return "Audio"
        case .text: return "Script"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startVideoPlayback() {
        guard let filename = content.filename else { return }
        let url = FileVault.url(for: filename)
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        newPlayer.play()
    }

    private func toggleAudioPlayback() {
        if let existingPlayer = player {
            if isPlayingAudio {
                existingPlayer.pause()
                isPlayingAudio = false
            } else {
                existingPlayer.play()
                isPlayingAudio = true
            }
        } else {
            guard let filename = content.filename else { return }
            let url = FileVault.url(for: filename)
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()
            isPlayingAudio = true
        }
    }
}
