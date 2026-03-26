import SwiftUI

/// Lazy API key entry sheet triggered on first transcription attempt when no key is configured.
///
/// Per UI-SPEC Screen 6 and D-13:
/// - Presented as a `.sheet` from `ContentDetailView` when `TranscriptionError.noAPIKey` is caught
/// - Matches the same SecureField + eye toggle pattern used in SettingsView (D-14)
/// - On save, dismisses sheet and calls `onSave` which retries transcription automatically
///
/// Sheet title: "OpenAI API Key Required" (Copywriting Contract)
struct APIKeyPromptSheet: View {
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var showAPIKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showAPIKey {
                            TextField("sk-...", text: $apiKey)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .textContentType(.password)
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(showAPIKey ? Theme.accent : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save API Key") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        try? KeychainService.save(key: "openai_api_key", value: trimmed)
                        dismiss()
                        // Trigger retry after brief delay for dismiss animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onSave()
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Required for AI transcription. Text-only scripts don't need a key.")
                }
            }
            .navigationTitle("OpenAI API Key Required")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
