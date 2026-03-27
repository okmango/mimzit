import SwiftUI

/// A single row in the session history list.
///
/// Displays the reference content thumbnail, title, date/time, and duration.
/// Thumbnail is resolved from the reference content lookup dictionary passed in.
struct SessionRowView: View {
    let session: Session
    /// Optional thumbnail filename from the associated ReferenceContent (may be nil for audio/text).
    let thumbnailFilename: String?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 60, height: 44)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.referenceContentTitle)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(session.recordedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text(formattedDuration)
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var formattedDuration: String {
        let mins = Int(session.duration) / 60
        let secs = Int(session.duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let filename = thumbnailFilename,
           let uiImage = UIImage(contentsOfFile: FileVault.url(for: filename).path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "waveform")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
        }
    }
}
