import SwiftUI

/// Library list row displaying type icon, title, duration, and transcript badge.
///
/// Per UI-SPEC Component Inventory:
/// - Type icon: 32pt frame, colored SF Symbol per content type
/// - Title: `.headline`, 1 line truncated
/// - Type label: `.caption`, `.secondary`
/// - Duration: right-aligned, `.caption`, `.secondary` (omitted for scripts since duration is nil)
/// - Transcript badge: green checkmark only when transcript exists
struct ContentItemRow: View {
    let content: ReferenceContent

    private var typeIcon: (name: String, color: Color) {
        switch content.contentType {
        case .video: return ("film", Theme.videoColor)
        case .audio: return ("waveform", Theme.audioColor)
        case .text: return ("doc.text", Theme.scriptColor)
        }
    }

    private var typeLabel: String {
        switch content.contentType {
        case .video: return "Video"
        case .audio: return "Audio"
        case .text: return "Script"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon.name)
                .foregroundStyle(typeIcon.color)
                .frame(width: 32, height: 32)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let duration = content.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if content.transcript != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.transcriptReady)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
