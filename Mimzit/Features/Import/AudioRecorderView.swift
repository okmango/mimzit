import SwiftUI
import AVFoundation

/// Recording mode determines what happens after the user stops recording.
enum RecordingMode {
    /// Save as audio content — file stored via FileVault.
    case audio
    /// Transcribe immediately via Whisper and save as text content.
    case dictation
}

/// Modal recording sheet with a live timer and record/stop control.
///
/// Used for both "Record Audio" (saves .m4a file) and "Dictate Script"
/// (records, then transcribes via Whisper before returning text).
struct AudioRecorderView: View {
    let mode: RecordingMode
    let onSaveAudio: ((URL, TimeInterval) -> Void)?
    let onSaveScript: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var recorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var timer: Timer?
    @State private var recordedURL: URL?
    @State private var isTranscribing = false
    @State private var errorMessage: String?

    private let outputURL: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("m4a")

    init(mode: RecordingMode, onSaveAudio: ((URL, TimeInterval) -> Void)? = nil, onSaveScript: ((String) -> Void)? = nil) {
        self.mode = mode
        self.onSaveAudio = onSaveAudio
        self.onSaveScript = onSaveScript
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Timer display
                Text(formatTime(elapsedSeconds))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .foregroundStyle(isRecording ? .primary : .secondary)

                // Status
                if isTranscribing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Transcribing...")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Record / Stop button
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 4)
                            .frame(width: 72, height: 72)

                        if isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.red)
                                .frame(width: 28, height: 28)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .disabled(isTranscribing)

                Text(isRecording ? "Tap to stop" : (recordedURL == nil ? "Tap to record" : "Recording saved"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationTitle(mode == .audio ? "Record Audio" : "Dictate Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        cleanup()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isTranscribing)
                }
            }
            .onDisappear {
                timer?.invalidate()
                recorder?.stop()
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        errorMessage = nil
        recordedURL = nil
        elapsedSeconds = 0

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: outputURL, settings: settings)
            recorder?.record()
            isRecording = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let r = recorder, r.isRecording {
                    elapsedSeconds = r.currentTime
                }
            }
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        recordedURL = outputURL

        switch mode {
        case .audio:
            let duration = elapsedSeconds
            onSaveAudio?(outputURL, duration)
            dismiss()

        case .dictation:
            transcribeAndSave()
        }
    }

    private func transcribeAndSave() {
        isTranscribing = true
        Task {
            do {
                guard let apiKey = KeychainService.load(key: "openai_api_key"),
                      !apiKey.isEmpty else {
                    errorMessage = "No API key configured. Add your OpenAI key in Settings first."
                    isTranscribing = false
                    return
                }

                let client = WhisperAPIClient(apiKey: apiKey)
                let transcript = try await client.transcribe(audioFileURL: outputURL)
                onSaveScript?(transcript)
                cleanup()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isTranscribing = false
            }
        }
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: outputURL)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }
}
