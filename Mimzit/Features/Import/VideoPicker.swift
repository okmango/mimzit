import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// UIViewControllerRepresentable wrapping PHPickerViewController for video import.
///
/// ## Why PHPickerViewController, not SwiftUI PhotosPicker.loadTransferable?
/// `loadTransferable(type: URL.self)` is unreliable for video on iOS 16–17.
/// PHPickerViewController with `loadFileRepresentation` is the correct approach.
///
/// ## CRITICAL: File copy inside callback
/// The temporary URL from `loadFileRepresentation` is invalidated when the callback returns.
/// The file MUST be copied synchronously within the callback (RESEARCH Pitfall 1).
/// VideoPicker performs the copy inside the callback and delivers the sandbox URL via `onPick`.
struct VideoPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                onCancel()
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                guard let url else {
                    DispatchQueue.main.async { self?.onCancel() }
                    return
                }
                // CRITICAL: Copy file INSIDE this callback before URL is invalidated
                let filename = "\(UUID().uuidString).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)"
                let destURL = FileVault.url(for: filename)
                do {
                    try FileVault.prepareDirectory()
                    try FileManager.default.copyItem(at: url, to: destURL)
                    DispatchQueue.main.async { self?.onPick(destURL) }
                } catch {
                    DispatchQueue.main.async { self?.onCancel() }
                }
            }
        }
    }
}
