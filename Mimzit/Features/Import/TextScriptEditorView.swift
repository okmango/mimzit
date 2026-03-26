import SwiftUI

/// Modal sheet for typing and saving a text script as reference content.
///
/// Per UI-SPEC Screen 4:
/// - TextEditor full-height, `.body` font
/// - Placeholder "Start typing your script..." per Copywriting Contract
/// - "Save Script" disabled when text is empty (trimmed)
/// - "Cancel" in leading position, "Save Script" in trailing
/// - Nav title: "New Script"
///
/// The `onSave` callback receives (title, text). Title is passed as empty string —
/// ContentLibraryView uses a fallback of "Untitled Script" when title is empty.
struct TextScriptEditorView: View {
    let onSave: (String, String) -> Void  // (title, text)
    @Environment(\.dismiss) private var dismiss
    @State private var scriptText = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $scriptText)
                .font(.body)
                .padding(.horizontal, 16)
                .overlay(alignment: .topLeading) {
                    if scriptText.isEmpty {
                        Text("Start typing your script...")
                            .foregroundStyle(.tertiary)
                            .font(.body)
                            .padding(.horizontal, 21)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .navigationTitle("New Script")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save Script") {
                            onSave("", scriptText.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                        .disabled(scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}

#Preview {
    TextScriptEditorView { title, text in
        print("Saved: \(title), \(text)")
    }
}
