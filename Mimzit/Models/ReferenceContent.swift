import SwiftData
import Foundation

/// Content type variants for imported reference material.
enum ContentType: String, Codable {
    case video
    case audio
    case text
}

/// Persistent model for a single piece of imported reference content.
///
/// ## Storage Strategy
/// Binary files (video, audio) are stored on disk via FileVault.
/// Only relative filenames are stored here — FileVault resolves to absolute URLs at runtime.
/// Text content (scripts) is stored inline via `scriptText` since there is no binary file.
///
/// ## Field Lifecycle
/// - `filename`: Set on import, nil for text content
/// - `duration`: Set on import from AVAsset, nil for text content
/// - `transcript`: Set after Whisper transcription completes
/// - `thumbnailFilename`: Set after poster frame extraction (Phase 2)
/// - `scriptText`: Set on script entry, nil for video/audio
@Model
final class ReferenceContent {
    var id: UUID
    var title: String
    var contentType: ContentType
    var createdAt: Date

    /// Relative filename in Documents/content/ — nil for text content.
    var filename: String?

    /// Duration in seconds — nil for text content.
    var duration: TimeInterval?

    /// Whisper transcript — set after transcription, nil until then.
    var transcript: String?

    /// Relative thumbnail filename in Documents/content/ — nil for audio/text.
    var thumbnailFilename: String?

    /// Inline script text for text content type — nil for video/audio.
    var scriptText: String?

    init(
        title: String,
        contentType: ContentType,
        filename: String? = nil,
        duration: TimeInterval? = nil,
        transcript: String? = nil,
        thumbnailFilename: String? = nil,
        scriptText: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.contentType = contentType
        self.createdAt = Date()
        self.filename = filename
        self.duration = duration
        self.transcript = transcript
        self.thumbnailFilename = thumbnailFilename
        self.scriptText = scriptText
    }
}
