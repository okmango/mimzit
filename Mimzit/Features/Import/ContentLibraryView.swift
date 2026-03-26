import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

/// Home screen content library showing all imported reference content.
///
/// Per UI-SPEC Screen 1 and Screen 3:
/// - Empty state: EmptyLibraryView centered
/// - Populated: List with ContentItemRow rows, swipe-to-delete
/// - Navigation: "+ " button in trailing toolbar launches confirmation dialog
/// - Three import paths: Import Video (PHPickerViewController), Import Audio (fileImporter),
///   Type a Script (TextScriptEditorView sheet)
struct ContentLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReferenceContent.createdAt, order: .reverse) private var items: [ReferenceContent]

    @State private var showAddDialog = false
    @State private var showVideoPicker = false
    @State private var showAudioPicker = false
    @State private var showScriptEditor = false
    @State private var selectedItem: ReferenceContent?
    @State private var itemToDelete: ReferenceContent?
    @State private var showDeleteConfirmation = false
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyLibraryView()
                } else {
                    List {
                        ForEach(items) { item in
                            ContentItemRow(content: item)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedItem = item }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        itemToDelete = item
                                        showDeleteConfirmation = true
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddDialog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add reference content")
                }
            }
            .confirmationDialog("Add Reference Content", isPresented: $showAddDialog, titleVisibility: .visible) {
                Button("Import Video") { showVideoPicker = true }
                Button("Import Audio") { showAudioPicker = true }
                Button("Type a Script") { showScriptEditor = true }
            }
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker(
                    onPick: { copiedURL in
                        Task { await handleVideoImport(copiedURL: copiedURL) }
                        showVideoPicker = false
                    },
                    onCancel: { showVideoPicker = false }
                )
            }
            .fileImporter(
                isPresented: $showAudioPicker,
                allowedContentTypes: [.audio, .mpeg4Audio, .mp3],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await importAudio(from: url) }
                }
            }
            .sheet(isPresented: $showScriptEditor) {
                TextScriptEditorView { title, text in
                    saveScript(title: title, text: text)
                }
            }
            .sheet(item: $selectedItem) { item in
                ContentDetailView(content: item)
            }
            .alert("Delete Content?", isPresented: $showDeleteConfirmation) {
                Button("Keep", role: .cancel) { itemToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete { deleteItem(item) }
                    itemToDelete = nil
                }
            } message: {
                Text("This will permanently remove this item and its transcript from your library.")
            }
            .overlay {
                if isImporting {
                    ProgressView()
                        .controlSize(.large)
                }
            }
        }
    }

    // MARK: - Import Handlers

    private func handleVideoImport(copiedURL: URL) async {
        isImporting = true
        defer { isImporting = false }

        let filename = copiedURL.lastPathComponent

        // Get video duration
        let asset = AVAsset(url: copiedURL)
        let duration: TimeInterval? = try? await CMTimeGetSeconds(asset.load(.duration))

        // Generate thumbnail
        var thumbFilename: String? = nil
        if let cgImage = try? await generateThumbnail(from: copiedURL) {
            let thumbName = "\(UUID().uuidString).jpg"
            let thumbURL = FileVault.url(for: thumbName)
            if let jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7) {
                try? jpegData.write(to: thumbURL)
                thumbFilename = thumbName
            }
        }

        let title = copiedURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let item = ReferenceContent(
            title: title,
            contentType: .video,
            filename: filename,
            duration: duration,
            thumbnailFilename: thumbFilename
        )
        modelContext.insert(item)
    }

    private func generateThumbnail(from url: URL) async throws -> CGImage {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)
        let (image, _) = try await generator.image(at: .zero)
        return image
    }

    private func importAudio(from securityScopedURL: URL) async {
        guard securityScopedURL.startAccessingSecurityScopedResource() else { return }
        defer { securityScopedURL.stopAccessingSecurityScopedResource() }

        isImporting = true
        defer { isImporting = false }

        let ext = securityScopedURL.pathExtension.isEmpty ? "m4a" : securityScopedURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"

        do {
            _ = try FileVault.store(sourceURL: securityScopedURL, filename: filename)
        } catch { return }

        // Get audio duration
        let storedURL = FileVault.url(for: filename)
        let asset = AVAsset(url: storedURL)
        let duration: TimeInterval? = try? await CMTimeGetSeconds(asset.load(.duration))

        let title = securityScopedURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let item = ReferenceContent(
            title: title,
            contentType: .audio,
            filename: filename,
            duration: duration
        )
        modelContext.insert(item)
    }

    private func saveScript(title: String, text: String) {
        let item = ReferenceContent(
            title: title.isEmpty ? "Untitled Script" : title,
            contentType: .text,
            scriptText: text
        )
        modelContext.insert(item)
    }

    private func deleteItem(_ item: ReferenceContent) {
        if let filename = item.filename {
            try? FileVault.delete(filename: filename)
        }
        if let thumb = item.thumbnailFilename {
            try? FileVault.delete(filename: thumb)
        }
        modelContext.delete(item)
    }
}

#Preview {
    ContentLibraryView()
        .modelContainer(for: ReferenceContent.self, inMemory: true)
}
