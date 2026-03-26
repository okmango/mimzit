import Foundation
import AVFoundation

/// Errors that can occur during the transcription pipeline.
enum TranscriptionError: LocalizedError {
    case noNetwork
    case noAPIKey
    case textContentNotSupported
    case audioExtractionFailed
    case fileTooLarge
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "Transcription failed. Check your connection and try again."
        case .noAPIKey:
            return "OpenAI API Key Required"
        case .textContentNotSupported:
            return "Text content cannot be transcribed."
        case .audioExtractionFailed:
            return "Failed to extract audio from video."
        case .fileTooLarge:
            return "Audio is too long to transcribe. Try a shorter clip."
        case .apiError(let msg):
            return msg
        }
    }
}

/// Orchestrates the full Whisper transcription pipeline for ReferenceContent.
///
/// ## Pipeline
/// 1. Guard: network available + API key configured
/// 2. Audio source: extract audio from video (AVAssetExportSession) or use audio file directly
/// 3. Preprocess: silence removal + 1.5x speedup via AudioPreprocessor (TRANS-02)
/// 4. Size check: guard against 25MB Whisper limit
/// 5. Transcribe: POST to Whisper API via WhisperAPIClient (TRANS-01)
///
/// ## Usage
/// ```swift
/// let service = TranscriptionService()
/// let transcript = try await service.transcribe(content: referenceContent)
/// ```
///
/// Uses `@Observable` (iOS 17+) per RESEARCH recommendation for greenfield SwiftUI apps.
/// `@MainActor` ensures `isTranscribing` state changes are applied on the main thread.
@Observable
@MainActor
final class TranscriptionService {
    private let networkMonitor = NetworkMonitor()
    private let preprocessor = AudioPreprocessor()

    /// True while a transcription is in progress — drives ProgressView in UI.
    private(set) var isTranscribing = false

    /// Transcribes the audio content of a ReferenceContent item.
    ///
    /// - Parameter content: The ReferenceContent to transcribe. Must be `.video` or `.audio`.
    /// - Returns: The transcript string from Whisper.
    /// - Throws: `TranscriptionError` for any failure condition.
    func transcribe(content: ReferenceContent) async throws -> String {
        guard networkMonitor.isConnected else { throw TranscriptionError.noNetwork }
        guard let apiKey = KeychainService.load(key: "openai_api_key"),
              !apiKey.isEmpty else { throw TranscriptionError.noAPIKey }

        isTranscribing = true
        defer { isTranscribing = false }

        let audioURL: URL
        switch content.contentType {
        case .video:
            guard let filename = content.filename else {
                throw TranscriptionError.audioExtractionFailed
            }
            let videoURL = FileVault.url(for: filename)
            audioURL = try await extractAudio(from: videoURL)
        case .audio:
            guard let filename = content.filename else {
                throw TranscriptionError.audioExtractionFailed
            }
            audioURL = FileVault.url(for: filename)
        case .text:
            throw TranscriptionError.textContentNotSupported
        }

        // Preprocess: silence removal + 1.5x speedup (TRANS-02)
        let processedURL = try await preprocessor.process(inputURL: audioURL)
        defer { try? FileManager.default.removeItem(at: processedURL) }

        // Check 25 MB Whisper limit
        let attrs = try FileManager.default.attributesOfItem(atPath: processedURL.path)
        if let size = attrs[.size] as? Int, size >= 25_000_000 {
            throw TranscriptionError.fileTooLarge
        }

        // Call Whisper API (TRANS-01)
        let client = WhisperAPIClient(apiKey: apiKey)
        let transcript = try await client.transcribe(audioFileURL: processedURL)
        return transcript
    }

    // MARK: - Private: Audio Extraction

    /// Extracts the audio track from a video file as .m4a (TRANS-02 prerequisite).
    ///
    /// Uses AVAssetExportPresetAppleM4A to produce a standard m4a file suitable
    /// for the AudioPreprocessor and the Whisper API.
    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw TranscriptionError.audioExtractionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: .zero,
            duration: try await asset.load(.duration)
        )

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw TranscriptionError.audioExtractionFailed
        }
        return outputURL
    }
}
