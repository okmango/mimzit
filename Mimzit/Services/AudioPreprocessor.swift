import AVFoundation
import Accelerate

/// Errors that can occur during audio preprocessing.
enum AudioPreprocessorError: LocalizedError {
    case noAudioTrack
    case compositionFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in the recording."
        case .compositionFailed:
            return "Failed to create audio composition for speed adjustment."
        case .exportFailed:
            return "Failed to export preprocessed audio."
        }
    }
}

/// Two-stage audio preprocessing pipeline that reduces Whisper API costs
/// by removing silence and speeding up audio with pitch preservation.
///
/// ## Stage 1: Silence Removal
/// Uses vDSP RMS energy analysis with a 0.01 threshold to drop silent chunks.
///
/// ## Stage 2: 1.5x Speed-up
/// Uses AVMutableComposition `scaleTimeRange` with `.timeDomain` pitch algorithm
/// to compress audio duration without chipmunk effect.
///
/// Copied verbatim from sezit/Sezit/Services/AudioPreprocessor.swift.
struct AudioPreprocessor {

    /// RMS threshold below which a chunk is considered silence.
    private let silenceThreshold: Float = 0.01

    /// Speed multiplier for the time-compression stage.
    private let speedMultiplier: Double = 1.5

    /// Processes audio through the two-stage pipeline: silence removal then speed-up.
    /// - Parameter inputURL: URL of the original audio file.
    /// - Returns: URL of the preprocessed audio file in the temporary directory.
    func process(inputURL: URL) async throws -> URL {
        let desilencedURL = try removeSilence(from: inputURL)
        let optimizedURL = try await speedUp(audioURL: desilencedURL)

        // Clean up intermediate file
        try? FileManager.default.removeItem(at: desilencedURL)

        return optimizedURL
    }

    // MARK: - Stage 1: Silence Removal

    /// Removes silent chunks from audio based on RMS energy.
    /// - Parameter inputURL: URL of the audio file to process.
    /// - Returns: URL of the desilenced audio file.
    func removeSilence(from inputURL: URL) throws -> URL {
        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("desilenced.m4a")

        // Remove existing file at output path (idempotent)
        try? FileManager.default.removeItem(at: outputURL)

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: inputFile.fileFormat.settings)
        let bufferCapacity: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) else {
            throw AudioPreprocessorError.compositionFailed
        }

        while inputFile.framePosition < inputFile.length {
            try inputFile.read(into: buffer)
            let frameLength = buffer.frameLength
            guard frameLength > 0 else { break }

            // Compute RMS using vDSP
            guard let channelData = buffer.floatChannelData?[0] else { continue }
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))

            // Keep only non-silent chunks
            if rms > silenceThreshold {
                try outputFile.write(from: buffer)
            }
        }

        return outputURL
    }

    // MARK: - Stage 2: Speed-Up with Pitch Preservation

    /// Speeds up audio using AVMutableComposition with pitch-preserved time scaling.
    /// - Parameter audioURL: URL of the audio file to speed up.
    /// - Returns: URL of the sped-up audio file.
    func speedUp(audioURL: URL) async throws -> URL {
        let asset = AVAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .audio)

        guard let sourceTrack = tracks.first else {
            throw AudioPreprocessorError.noAudioTrack
        }

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioPreprocessorError.compositionFailed
        }

        let fullRange = CMTimeRange(start: .zero, duration: duration)
        try compositionTrack.insertTimeRange(fullRange, of: sourceTrack, at: .zero)

        // Scale time range to achieve speed-up
        let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / speedMultiplier)
        composition.scaleTimeRange(fullRange, toDuration: scaledDuration)

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("optimized.m4a")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioPreprocessorError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioTimePitchAlgorithm = .timeDomain

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioPreprocessorError.exportFailed
        }

        return outputURL
    }
}
