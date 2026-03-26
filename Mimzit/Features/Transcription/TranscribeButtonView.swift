import SwiftUI

/// Three-state view representing the transcription lifecycle for a content item.
///
/// Per UI-SPEC Component Inventory "TranscribeButton":
/// - `.idle` — tappable "Transcribe Audio" button with waveform icon
/// - `.inProgress` — non-interactive spinner + label while Whisper API call is in flight
/// - `.complete` — read-only "Transcript ready" checkmark indicator
/// - `.error` — button re-shown with inline error message below in caption red
///
/// Used inside `ContentDetailView.transcriptSection` for `.video` and `.audio` content only.
enum TranscribeState {
    case idle
    case inProgress
    case complete
    case error(String)
}

struct TranscribeButtonView: View {
    let state: TranscribeState
    let onTranscribe: () -> Void

    var body: some View {
        switch state {
        case .idle:
            Button(action: onTranscribe) {
                Label("Transcribe Audio", systemImage: "waveform.badge.sparkles")
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)

        case .inProgress:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Theme.accent)
                Text("Transcribing...")
                    .foregroundStyle(.secondary)
            }

        case .complete:
            Label("Transcript ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.transcriptReady)
                .font(.caption)

        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onTranscribe) {
                    Label("Transcribe Audio", systemImage: "waveform.badge.sparkles")
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
