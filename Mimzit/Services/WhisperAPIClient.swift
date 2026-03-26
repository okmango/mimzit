import Foundation

/// Errors that can occur during Whisper API transcription.
enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, body: String?)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing. Please add your OpenAI API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from the transcription service."
        case let .apiError(statusCode, body):
            if statusCode == 401 {
                return "Invalid API key. Please check your OpenAI API key in Settings."
            } else if statusCode == 429 {
                return "Rate limit exceeded. Please wait a moment and try again."
            } else if let body = body, !body.isEmpty {
                return "Transcription failed: \(body)"
            } else {
                return "Transcription failed with error code \(statusCode)."
            }
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    /// Whether this error is potentially transient and retryable.
    var isRetryable: Bool {
        switch self {
        case .missingAPIKey, .invalidResponse:
            return false
        case let .apiError(statusCode, _):
            // Retry on rate limit (429) or server errors (5xx)
            return statusCode == 429 || (statusCode >= 500 && statusCode < 600)
        case .networkError:
            return true
        }
    }
}

/// Response from the Whisper API transcription endpoint.
private struct WhisperResponse: Decodable {
    let text: String
}

/// Client for OpenAI's Whisper transcription API.
///
/// ## Usage
/// ```swift
/// let client = WhisperAPIClient(apiKey: apiKey)
/// let transcript = try await client.transcribe(audioFileURL: audioURL)
/// ```
///
/// Copied from sezit/Sezit/Services/WhisperAPIClient.swift.
/// No changes required — the file uses no sezit-specific types.
struct WhisperAPIClient {
    private let apiKey: String
    private let transcriptionEndpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let translationEndpoint = URL(string: "https://api.openai.com/v1/audio/translations")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Transcribes an audio file using the Whisper API.
    ///
    /// - Parameters:
    ///   - audioFileURL: Local file URL of the audio to transcribe.
    ///   - translateToEnglish: If true, uses the translation endpoint to convert any language to English.
    /// - Returns: The transcribed (or translated) text.
    /// - Throws: `WhisperError` on failure.
    func transcribe(audioFileURL: URL, translateToEnglish: Bool = false) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        let endpoint = translateToEnglish ? translationEndpoint : transcriptionEndpoint

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioFileURL)
        } catch {
            throw WhisperError.networkError(error)
        }

        let fileName = audioFileURL.lastPathComponent
        request.httpBody = createMultipartBody(
            audioData: audioData,
            fileName: fileName,
            model: "whisper-1",
            boundary: boundary
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WhisperError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8)
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, body: bodyString)
        }

        do {
            let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return whisperResponse.text
        } catch {
            throw WhisperError.invalidResponse
        }
    }

    /// Creates multipart form data body for the Whisper API request.
    private func createMultipartBody(
        audioData: Data,
        fileName: String,
        model: String,
        boundary: String
    ) -> Data {
        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }
}
