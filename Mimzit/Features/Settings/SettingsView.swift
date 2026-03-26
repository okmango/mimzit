import SwiftUI

/// Settings screen with API key management and app info.
///
/// Per UI-SPEC Screen 5 and decisions D-14, D-15:
/// - OpenAI API section: dual-state (configured/unconfigured)
/// - Configured: green checkmark + masked key + "Clear API Key" destructive button
/// - Unconfigured: SecureField with eye toggle + "Save API Key" disabled when empty
/// - API key persisted in Keychain via KeychainService (not UserDefaults)
/// - About section with app version
///
/// Pattern adapted from carufus_whozit/Whozit/Features/Settings/SettingsView.swift
struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isConfigured = KeychainService.load(key: "openai_api_key") != nil
    @State private var showClearConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("••••••••••••••••")
                                .foregroundStyle(.secondary)
                        }
                        Button("Clear API Key", role: .destructive) {
                            showClearConfirmation = true
                        }
                    } else {
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
                            saveAPIKey()
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("OpenAI API")
                } footer: {
                    Text("Your API key is stored securely in Keychain. Get one at platform.openai.com")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Clear API Key?", isPresented: $showClearConfirmation) {
                Button("Keep", role: .cancel) {}
                Button("Clear", role: .destructive) { clearAPIKey() }
            } message: {
                Text("This will permanently remove your API key. You'll need to enter it again to use AI transcription.")
            }
        }
    }

    private func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? KeychainService.save(key: "openai_api_key", value: trimmed)
        apiKey = ""
        showAPIKey = false
        isConfigured = true
    }

    private func clearAPIKey() {
        KeychainService.delete(key: "openai_api_key")
        isConfigured = false
        apiKey = ""
    }
}

#Preview {
    SettingsView()
}
