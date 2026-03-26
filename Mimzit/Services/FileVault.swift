import Foundation

/// Manages binary file storage in the app's Documents/content/ sandbox directory.
///
/// ## Storage Strategy
/// All media files (video, audio) are stored in `Documents/content/` via FileVault.
/// Only relative filenames are stored in SwiftData (ReferenceContent.filename).
/// FileVault resolves relative filenames to absolute URLs at runtime.
///
/// ## Why not SwiftData for files?
/// SwiftData (and CoreData) are not designed for binary large objects.
/// Storing video bytes in the database causes severe performance issues.
///
/// ## Usage
/// ```swift
/// let filename = try FileVault.store(sourceURL: pickedURL, filename: "\(UUID().uuidString).mp4")
/// let playbackURL = FileVault.url(for: filename)
/// ```
enum FileVault {

    private static var contentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("content", isDirectory: true)
    }

    /// Ensures the Documents/content/ directory exists.
    /// Safe to call multiple times — createDirectory with intermediateDirectories is idempotent.
    static func prepareDirectory() throws {
        try FileManager.default.createDirectory(
            at: contentDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Copies a file to the Documents/content/ directory.
    ///
    /// - Parameters:
    ///   - sourceURL: The source file URL (e.g., a PhotosPicker temp URL or Files picker URL)
    ///   - filename: The desired filename (typically `UUID().uuidString + ".mp4"`)
    /// - Returns: The relative filename stored in Documents/content/
    /// - Throws: FileManager errors if copy fails
    static func store(sourceURL: URL, filename: String) throws -> String {
        try prepareDirectory()
        let destination = contentDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return filename
    }

    /// Resolves a relative filename to an absolute URL in Documents/content/.
    ///
    /// - Parameter filename: The relative filename stored in ReferenceContent.filename
    /// - Returns: The absolute URL for playback or processing
    static func url(for filename: String) -> URL {
        contentDirectory.appendingPathComponent(filename)
    }

    /// Deletes a file from Documents/content/.
    ///
    /// Silently succeeds if the file doesn't exist.
    /// - Parameter filename: The relative filename to delete
    static func delete(filename: String) throws {
        let fileURL = contentDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Checks whether a file exists in Documents/content/.
    ///
    /// - Parameter filename: The relative filename to check
    /// - Returns: `true` if the file exists on disk
    static func fileExists(_ filename: String) -> Bool {
        FileManager.default.fileExists(
            atPath: contentDirectory.appendingPathComponent(filename).path
        )
    }
}
