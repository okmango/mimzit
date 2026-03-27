import SwiftData
import Foundation

/// Persistent model for a single practice session.
///
/// ## Storage Strategy
/// The user's recording file (mov) is stored on disk via FileVault.sessionsDirectory.
/// Only the relative filename is stored here — FileVault.sessionURL(for:) resolves at runtime.
///
/// ## Denormalized Reference Title
/// `referenceContentTitle` is stored inline to avoid a SwiftData @Relationship (which would
/// cascade-delete sessions when reference content is deleted). Store the UUID only for
/// re-linking if the content still exists.
///
/// ## Sync Alignment
/// `syncTimestamp` (CACurrentMediaTime at recording start) is used during review playback
/// to align the reference video and user recording correctly (REC-05).
@Model
final class Session {
    var id: UUID
    var recordedAt: Date
    var duration: TimeInterval
    var syncTimestamp: Double
    var recordingFilename: String

    /// UUID of the associated ReferenceContent — stored as plain UUID, not @Relationship.
    var referenceContentID: UUID

    /// Denormalized title for display without a join (avoids cascade-delete risk).
    var referenceContentTitle: String

    init(
        recordedAt: Date = Date(),
        duration: TimeInterval,
        syncTimestamp: Double,
        recordingFilename: String,
        referenceContentID: UUID,
        referenceContentTitle: String
    ) {
        self.id = UUID()
        self.recordedAt = recordedAt
        self.duration = duration
        self.syncTimestamp = syncTimestamp
        self.recordingFilename = recordingFilename
        self.referenceContentID = referenceContentID
        self.referenceContentTitle = referenceContentTitle
    }
}
