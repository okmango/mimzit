# Phase 1: Foundation + Import + Transcription - Research

**Researched:** 2026-03-25
**Domain:** iOS native app foundation — XcodeGen scaffolding, SwiftData models, AVAudioSession configuration, PhotosPicker + DocumentPicker imports, FileManager sandbox, Keychain credential storage, OpenAI Whisper API with audio preprocessing
**Confidence:** HIGH (Apple system frameworks, sibling project code verified directly)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Single-target app with XcodeGen (project.yml), consistent with sezit and carufus_whozit

**D-02:** Feature-based folder organization:
- `Mimzit/Features/Import/`
- `Mimzit/Features/Transcription/`
- `Mimzit/Features/Settings/`
- `Mimzit/App/`
- `Mimzit/Models/`
- `Mimzit/Services/`
- `Mimzit/Shared/Components/`
- `Mimzit/Resources/`

**D-03:** Copy and adapt reusable code from sibling projects — no cross-project dependencies. Sources: KeychainService from carufus_whozit, AudioPreprocessor + WhisperAPIClient from sezit

**D-04:** Use carufus_whozit as primary reference for organization, patterns, and UI/UX quality. Use sezit for OpenAI communication classes and settings/onboarding patterns

**D-05:** Home screen is a content library showing all imported items. Each item shows type icon, title, duration. '+' button to add new content

**D-06:** '+' button shows action sheet with 3 options: Import Video, Import Audio, Type Script

**D-07:** SwiftUI PhotosPicker for video import (Camera Roll, mp4/mov). DocumentPicker for audio import (Files app, m4a/mp3). Inline text editor for script entry

**D-08:** Tap content item to see inline detail/preview: video thumbnail with play, audio with play button, or text preview. 'Start Practice' button at bottom (wired in Phase 2)

**D-09:** Manual transcription — 'Transcribe' button on content detail screen. User explicitly requests it

**D-10:** Inline progress — button becomes progress indicator, transcript text appears in place when done. No modal, no navigation change

**D-11:** Whisper API only for Phase 1 — no Apple Speech fallback. TRANS-04 (SFSpeechRecognizer fallback) is deferred to a later phase

**D-12:** Audio preprocessing (silence removal + 1.5x speedup) always runs transparently before Whisper API call. Reuse sezit AudioPreprocessor pattern

**D-13:** API key prompt triggered on first transcription attempt, not during onboarding. Users who import text-only content are never asked

**D-14:** API key entry UI follows carufus_whozit SettingsView pattern: SecureField with eye toggle, Save button, checkmark when configured, stored in Keychain

**D-15:** Settings screen includes API key management section (same as whozit pattern: configured state with checkmark + clear button, unconfigured state with entry field)

### Claude's Discretion
- Specific SwiftData model schema design (fields, relationships)
- File storage structure within app sandbox (Documents vs Application Support)
- Network monitoring approach for API availability
- Theme/color choices for the app

### Deferred Ideas (OUT OF SCOPE)
- **TRANS-04 (SFSpeechRecognizer fallback):** Removed from Phase 1 scope. Whisper-only for now.
- **Onboarding flow:** Not needed in Phase 1 since API key is lazy-prompted.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | App configures AVAudioSession in .playAndRecord mode before any media engine starts | AVAudioSession configuration pattern documented in ARCHITECTURE.md; critical to call before any AVPlayer or AVCaptureSession is created |
| FOUND-02 | App disables AVCaptureSession.automaticallyConfiguresApplicationAudioSession | Must set to `false` immediately after creating AVCaptureSession; covered in architecture anti-patterns section |
| FOUND-03 | App detects headphone/AirPods connection and warns user if no headphones before recording | AVAudioSession.currentRoute inspection + routeChangeNotification pattern documented |
| FOUND-04 | App requests camera and microphone permissions with clear explanations before first use | AVCaptureDevice.requestAccess pattern; Info.plist keys NSCameraUsageDescription + NSMicrophoneUsageDescription required |
| FOUND-05 | OpenAI API key stored securely in iOS Keychain | KeychainService.swift from carufus_whozit is a direct copy-and-adapt source; service identifier change to `com.okmango.mimzit` |
| IMPORT-01 | User can import a reference video from Camera Roll via system picker (mp4/mov only) | PhotosUI.PhotosPicker with PHPickerFilter.videos; copy-to-sandbox pattern verified |
| IMPORT-02 | User can import an audio-only file from Files app (m4a/mp3) | SwiftUI `.fileImporter` modifier with UTType.audio content types; whozit uses this in SettingsView |
| IMPORT-03 | User can paste or type text as a reference script (text-only mode) | Inline SwiftUI TextEditor; no external dependency |
| IMPORT-04 | Imported content is stored locally in app sandbox with metadata (type: video/audio/text) | SwiftData @Model for metadata; FileManager Documents directory for binary files; relative filenames only |
| IMPORT-05 | User can preview imported reference content before starting a practice session | AVPlayer + AVPlayerLayer for video/audio preview; TextEditor/Text for script; all inside content detail view |
| TRANS-01 | User can request AI transcription of reference video/audio via OpenAI Whisper API | WhisperAPIClient from sezit is a direct copy-and-adapt; multipart/form-data POST to api.openai.com/v1/audio/transcriptions |
| TRANS-02 | Audio preprocessed before sending to Whisper (silence removal + 1.5x speedup) | AudioPreprocessor.swift from sezit is a direct copy; uses AVAudioFile + vDSP + AVMutableComposition |
| TRANS-03 | Transcription text saved alongside the reference content as synchronized transcript | SwiftData field on ReferenceContent model: `var transcript: String?` |
| TRANS-04 | (DEFERRED) Fallback to on-device SFSpeechRecognizer | Out of scope for Phase 1 per D-11 |

</phase_requirements>

---

## Summary

Phase 1 builds the entire non-recording infrastructure of Mimzit: the Xcode project, data models, file storage, audio session configuration, content import flows, and AI transcription pipeline. No camera capture or live recording happens in this phase — that is Phase 2's concern.

The technical work falls into five independent tracks that can be built in sequence: (1) XcodeGen project scaffold and app entry point, (2) SwiftData models and FileManager storage layer, (3) AVAudioSession configuration and headphone detection, (4) content import flows for all three content types, and (5) Whisper API transcription with audio preprocessing. The two sibling projects provide nearly all the reusable code needed — the plan is primarily about adapting existing code to the new domain, not writing from scratch.

The highest-risk item is the audio extraction pipeline: for video content, audio must be extracted from the video file before preprocessing and transcription. sezit's AudioPreprocessor works on audio URLs directly, so a pre-extraction step using AVAssetExportSession is required. The Whisper API has a 25 MB file size limit; the preprocessing pipeline (silence removal + 1.5x speedup) reliably reduces file size enough for typical reference content lengths.

**Primary recommendation:** Build in dependency order — scaffold first, models second, audio session third (foundation required before any media preview), imports fourth (requires models + sandbox), transcription last (requires imports + audio extraction). Do not attempt to wire the 'Start Practice' button; that is explicitly Phase 2 scope.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift | 5.10+ (Xcode 16) | Primary language | Only modern choice; async/await essential for Whisper API calls and audio export |
| SwiftUI | iOS 17+ | UI layer | Target is iOS 17+ (SwiftData requirement); PhotosPicker, .fileImporter, TextEditor all native |
| SwiftData | iOS 17+ | ReferenceContent metadata persistence | @Query binding eliminates list boilerplate; ModelContainer set up at app level per whozit pattern |
| AVFoundation | iOS 16+ | Audio session configuration, audio extraction from video, media preview | Apple-only framework; no alternative |
| AVAudioSession | iOS 16+ | .playAndRecord configuration at app launch | Singleton; configure once before any engine starts |
| PhotosUI | iOS 16+ | Video import from Camera Roll | Native SwiftUI PhotosPicker; no UIViewControllerRepresentable wrapper needed |
| FileManager | iOS 16+ | Binary file storage in Documents sandbox | Binary media must not enter SwiftData |
| Security (Keychain) | iOS 16+ | API key secure storage | kSecClassGenericPassword; whozit pattern is production-verified |
| Network (NWPathMonitor) | iOS 16+ | Connectivity check before Whisper API call | Lightweight; already in whozit's NetworkMonitor class |
| Accelerate (vDSP) | iOS 16+ | RMS silence detection in AudioPreprocessor | Zero-dependency; hardware-accelerated; already used in sezit |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVKit (VideoPlayer) | iOS 16+ | Video preview in content detail view | Use AVKit VideoPlayer for the preview-only detail screen — full AVPlayerLayer not needed here since there is no fader or layer manipulation in Phase 1 |
| AVAssetExportSession | iOS 16+ | Extract audio track from video before preprocessing | Required when content is a video file; exports audio-only m4a to temp directory before passing to AudioPreprocessor |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData | CoreData | CoreData if iOS 16 strict minimum required. iOS 17 target is justified per adoption stats. SwiftData saves significant boilerplate |
| sezit's WhisperAPIClient (raw URLSession) | OpenAI Swift package | whozit uses MacPaw/OpenAI SPM package; sezit's WhisperAPIClient is raw URLSession multipart. For Mimzit, use sezit's raw client — no SPM dependency needed, simpler, already adapts well to file URL input rather than Data |
| .fileImporter SwiftUI modifier | UIDocumentPickerViewController wrapped in UIViewControllerRepresentable | .fileImporter is native SwiftUI and cleaner; whozit uses it in SettingsView for zip files — same pattern works for audio |

### Installation
```bash
# No external dependencies for Phase 1.
# All frameworks are Apple system frameworks included with Xcode:
# AVFoundation, AVKit, PhotosUI, SwiftData, Security, Network, Accelerate
#
# project.yml will NOT include any SPM packages for Phase 1.
# (OpenAI SPM package is NOT needed — WhisperAPIClient uses raw URLSession)
```

---

## Architecture Patterns

### Recommended Project Structure
```
Mimzit/
├── App/
│   ├── MimzitApp.swift              # @main, ModelContainer setup, AudioSessionManager.configure()
│   └── ContentView.swift            # Root navigation (tab or NavigationStack — see below)
├── Features/
│   ├── Import/
│   │   ├── ContentLibraryView.swift  # Home screen: list of imported items
│   │   ├── ContentLibraryViewModel.swift
│   │   ├── ContentDetailView.swift   # Preview + Transcribe + Start Practice (disabled Phase 1)
│   │   ├── ContentDetailViewModel.swift
│   │   └── TextScriptEditorView.swift # Inline text entry for Type Script option
│   ├── Transcription/
│   │   └── TranscriptionService.swift # Whisper-only, wraps WhisperAPIClient + AudioPreprocessor
│   └── Settings/
│       └── SettingsView.swift         # API key section (whozit pattern)
├── Models/
│   └── ReferenceContent.swift        # SwiftData @Model
├── Services/
│   ├── AudioSessionManager.swift     # AVAudioSession singleton; configure() at launch
│   ├── KeychainService.swift         # Copy from whozit; change service to com.okmango.mimzit
│   ├── WhisperAPIClient.swift        # Copy from sezit; adapt to accept URL instead of Data
│   ├── AudioPreprocessor.swift       # Copy from sezit; unchanged
│   ├── FileVault.swift               # FileManager wrapper for Documents sandbox
│   └── NetworkMonitor.swift          # NWPathMonitor; copy from whozit's TranscriptionService inline class
├── Shared/
│   └── Components/                   # Reusable UI pieces (type icon, empty state view, etc.)
└── Resources/
    ├── Info.plist
    ├── Assets.xcassets
    └── Mimzit.entitlements
```

### Pattern 1: App Launch — Configure Audio Session Before Any Engine

**What:** `AVAudioSession` is a process-wide singleton. Its configuration must be committed before `AVPlayer` or `AVCaptureSession` is created. MimzitApp.init() is the correct call site.

**When to use:** Always. Not optional. Incorrect ordering causes silent audio routing failures.

**Example (adapt from ARCHITECTURE.md):**
```swift
// MimzitApp.swift — in App.init() before ModelContainer setup
@main
struct MimzitApp: App {
    let container: ModelContainer

    init() {
        // 1. Audio session FIRST — before any media engine
        AudioSessionManager.configure()

        // 2. SwiftData container
        do {
            container = try ModelContainer(
                for: ReferenceContent.self,
                migrationPlan: MimzitMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    // ...
}
```

**AudioSessionManager.configure():**
```swift
// Services/AudioSessionManager.swift
// Source: .planning/research/ARCHITECTURE.md Pattern 1
enum AudioSessionManager {
    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("AudioSession configuration failed: \(error)")
        }
    }
}
```

### Pattern 2: SwiftData Model — ReferenceContent

**What:** Single `@Model` class stores metadata for all imported content. Binary files (video, audio) stored in Documents sandbox via FileVault. Only relative filenames stored in SwiftData.

**When to use:** Always. Never store absolute URLs or binary data in SwiftData.

**Schema (Claude's discretion — recommended):**
```swift
// Models/ReferenceContent.swift
import SwiftData
import Foundation

enum ContentType: String, Codable {
    case video
    case audio
    case text
}

@Model
final class ReferenceContent {
    var id: UUID
    var title: String
    var contentType: ContentType
    var createdAt: Date

    // File-backed content (video/audio): relative filename in Documents/content/
    // Text content: nil
    var filename: String?

    // Duration in seconds (video/audio); nil for text
    var duration: TimeInterval?

    // Transcript — set after successful Whisper API call
    var transcript: String?

    // Thumbnail: relative filename for video poster frame; nil for audio/text
    var thumbnailFilename: String?

    init(
        title: String,
        contentType: ContentType,
        filename: String? = nil,
        duration: TimeInterval? = nil,
        transcript: String? = nil,
        thumbnailFilename: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.contentType = contentType
        self.createdAt = Date()
        self.filename = filename
        self.duration = duration
        self.transcript = transcript
        self.thumbnailFilename = thumbnailFilename
    }
}
```

**Migration plan — set up at v1 even if schema won't change yet:**
```swift
// Models/MimzitMigrationPlan.swift
import SwiftData

enum MimzitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] { [MimzitSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum MimzitSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [ReferenceContent.self] }
}
```

### Pattern 3: FileVault — Sandbox File Management

**What:** All file I/O through a single service. Stores files under `Documents/content/`. Returns relative filenames for SwiftData; resolves full URLs on demand.

**When to use:** Any time a file needs to be read or written to/from the sandbox.

**Example:**
```swift
// Services/FileVault.swift
enum FileVault {
    private static var contentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("content", isDirectory: true)
    }

    static func prepareDirectory() throws {
        try FileManager.default.createDirectory(
            at: contentDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Copies a file into the content directory and returns its relative filename.
    static func store(sourceURL: URL, filename: String) throws -> String {
        let destination = contentDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return filename
    }

    /// Resolves a relative filename to a full URL.
    static func url(for filename: String) -> URL {
        contentDirectory.appendingPathComponent(filename)
    }

    static func delete(filename: String) throws {
        let url = contentDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: url)
    }
}
```

### Pattern 4: Video Import via PhotosPicker

**What:** SwiftUI `PhotosPicker` with video filter; selected asset loaded via `PHPickerResult.itemProvider`; written to sandbox via FileVault.

**When to use:** IMPORT-01 — video from Camera Roll.

**Key detail:** PhotosPicker on iOS 16+ does NOT require a photo library permission prompt for reading. The picker is a system UI. However, after selection, `loadFileRepresentation(forTypeIdentifier:)` provides a temporary scoped URL that must be copied before the completion handler returns.

**Example:**
```swift
// Features/Import/ContentLibraryViewModel.swift
import PhotosUI

func handleVideoSelection(_ item: PhotosPickerItem?) async {
    guard let item else { return }
    guard let url = try? await item.loadTransferable(type: URL.self) else {
        // loadTransferable for URL is iOS 16+; may need itemProvider fallback
        // Use itemProvider path for reliability:
        return
    }
    // Copy to sandbox ...
}

// Reliable path via itemProvider for video files:
func importVideo(from result: PhotosPickerItem) async throws -> URL {
    let data = try await result.loadTransferable(type: Data.self)
    // OR use itemProvider:
    // result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) ...
}
```

**Note on PhotosPickerItem.loadTransferable:** For video, `loadTransferable(type: URL.self)` is NOT reliable on iOS 16 — it may return nil for non-iCloud assets. The reliable path is `loadTransferable(type: Data.self)` (loads full video bytes) or `itemProvider.loadFileRepresentation`. Loading full Data for large video files is memory-intensive. **Preferred approach:** Use `PHPickerViewController` delegate + `loadFileRepresentation(forTypeIdentifier:)` for a temporary file URL, then copy to sandbox. This is the pattern used in production iOS video apps.

```swift
// Preferred: UIViewControllerRepresentable wrapping PHPickerViewController
// The temporary URL from loadFileRepresentation must be copied synchronously
// within the callback before it is invalidated.
provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
    guard let url else { return }
    let filename = "\(UUID().uuidString).\(url.pathExtension)"
    let dest = FileVault.url(for: filename) // resolve temp destination
    try? FileManager.default.copyItem(at: url, to: dest)
    // Then create ReferenceContent with filename
}
```

### Pattern 5: Audio Import via .fileImporter

**What:** SwiftUI `.fileImporter` modifier with `UTType.audio` content types. Returns a security-scoped URL that must be accessed within `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` brackets.

**When to use:** IMPORT-02 — audio files from Files app.

**Example:**
```swift
// In ContentLibraryView
.fileImporter(
    isPresented: $showAudioPicker,
    allowedContentTypes: [.audio, .mpeg4Audio],  // m4a + mp3
    allowsMultipleSelection: false
) { result in
    if case .success(let urls) = result, let url = urls.first {
        Task { await viewModel.importAudio(from: url) }
    }
}

// In ViewModel
func importAudio(from securityScopedURL: URL) async {
    guard securityScopedURL.startAccessingSecurityScopedResource() else { return }
    defer { securityScopedURL.stopAccessingSecurityScopedResource() }

    let filename = "\(UUID().uuidString).\(securityScopedURL.pathExtension)"
    try? FileVault.store(sourceURL: securityScopedURL, filename: filename)
    // Create + save ReferenceContent ...
}
```

### Pattern 6: Whisper Transcription Pipeline

**What:** For video content, extract audio first. Then run AudioPreprocessor (silence removal + 1.5x speedup). Then call WhisperAPIClient. Save result to `ReferenceContent.transcript`.

**When to use:** TRANS-01, TRANS-02, TRANS-03.

**Audio extraction from video (new for Mimzit — not in sezit):**
```swift
// Services/TranscriptionService.swift — extractAudio helper
func extractAudio(from videoURL: URL) async throws -> URL {
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
```

**Full pipeline:**
```swift
// Services/TranscriptionService.swift
@MainActor
final class TranscriptionService: ObservableObject {
    private let whisperClient: WhisperAPIClient
    private let preprocessor = AudioPreprocessor()
    private let networkMonitor = NetworkMonitor()

    @Published private(set) var isTranscribing = false

    func transcribe(content: ReferenceContent) async throws -> String {
        guard networkMonitor.isConnected else {
            throw TranscriptionError.noNetwork
        }

        let audioURL: URL
        switch content.contentType {
        case .video:
            let videoURL = FileVault.url(for: content.filename!)
            let extracted = try await extractAudio(from: videoURL)
            audioURL = extracted
        case .audio:
            audioURL = FileVault.url(for: content.filename!)
        case .text:
            throw TranscriptionError.textContentNotSupported
        }

        let processedURL = try await preprocessor.process(inputURL: audioURL)
        defer { try? FileManager.default.removeItem(at: processedURL) }

        let transcript = try await whisperClient.transcribe(audioFileURL: processedURL)
        return transcript
    }
}
```

### Pattern 7: KeychainService — API Key Storage

**What:** Copy KeychainService.swift from carufus_whozit verbatim. Change only the service identifier.

**Change required:**
```swift
// Services/KeychainService.swift
private static let service = "com.okmango.mimzit"  // was "com.okmango.whozit"
```

**API key key constant:**
```swift
// In OpenAICredentialService or SettingsViewModel:
private static let apiKeyKeychainKey = "openai_api_key"
```

### Pattern 8: Headphone Detection (FOUND-03)

**What:** Check `AVAudioSession.sharedInstance().currentRoute.outputs` for headphone/AirPods port types. Subscribe to `routeChangeNotification` to detect changes at runtime.

**When to use:** FOUND-03 — warn before recording starts. This is foundation work; the UI warning fires in Phase 2 when recording begins. In Phase 1, implement the detection and expose a computed property.

**Example:**
```swift
// Services/AudioSessionManager.swift — add to existing manager
extension AudioSessionManager {
    static var headphonesConnected: Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
                .contains(output.portType)
        }
    }

    static func observeRouteChanges(handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in handler() }
    }
}
```

### Pattern 9: Permission Requests (FOUND-04)

**What:** Camera and microphone permissions requested lazily — camera on first recording attempt (Phase 2), microphone on first recording attempt (Phase 2). In Phase 1, add Info.plist usage description strings to project.yml.

**Info.plist keys required (in project.yml `info.properties`):**
```yaml
NSCameraUsageDescription: "Mimzit uses the camera to record your practice alongside the reference video."
NSMicrophoneUsageDescription: "Mimzit uses the microphone to capture your voice during practice sessions."
NSPhotoLibraryUsageDescription: "Mimzit reads videos from your photo library to use as reference content."
```

**Note:** `NSPhotoLibraryUsageDescription` is NOT required for PhotosPicker on iOS 16+ when only reading (not saving). However, App Store review may flag its absence. Include it as a belt-and-suspenders measure. It is required if saving thumbnails back to the library is ever needed.

### Pattern 10: XcodeGen project.yml Scaffold

**What:** Based on sezit's pattern (iOS 17 minimum), no SPM packages for Phase 1, portrait-only, Swift 6 strict concurrency optional for Phase 1.

**Recommended project.yml:**
```yaml
name: Mimzit
options:
  bundleIdPrefix: com.okmango
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.10"
    SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"
    SUPPORTS_MACCATALYST: false
    TARGETED_DEVICE_FAMILY: "1"  # iPhone only

targets:
  Mimzit:
    type: application
    platform: iOS
    sources:
      - path: Mimzit
        excludes:
          - "**/.DS_Store"
    info:
      path: Mimzit/Resources/Info.plist
      properties:
        NSCameraUsageDescription: "Mimzit uses the camera to record your practice alongside the reference video."
        NSMicrophoneUsageDescription: "Mimzit uses the microphone to capture your voice during practice sessions."
        NSPhotoLibraryUsageDescription: "Mimzit reads videos from your photo library to use as reference content."
        CFBundleURLTypes: []
        UISupportedInterfaceOrientations: ["UIInterfaceOrientationPortrait"]
    entitlements:
      path: Mimzit/Resources/Mimzit.entitlements
      properties:
        keychain-access-groups:
          - $(AppIdentifierPrefix)com.okmango.mimzit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.okmango.mimzit
        CODE_SIGN_STYLE: Automatic
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: 1
        GENERATE_INFOPLIST_FILE: false
```

### Anti-Patterns to Avoid

- **Using SwiftUI `PhotosPicker.loadTransferable(type: URL.self)` for video:** Unreliable on iOS 16–17 for video. Use `loadTransferable(type: Data.self)` (memory-heavy) or PHPickerViewController delegate with `loadFileRepresentation` (correct approach for large files).
- **Storing absolute URLs in SwiftData:** Container UUID changes on reinstall. Store only relative filenames; resolve at runtime via FileVault.
- **Calling `setCategory` in AVCaptureSession path:** Never call setCategory after AudioSessionManager.configure(). Always set `captureSession.automaticallyConfiguresApplicationAudioSession = false`.
- **Sending video data directly to Whisper without audio extraction:** Whisper API accepts audio formats (m4a, mp3, wav, webm, ogg) but NOT mp4 with only video track. Always extract audio track first.
- **Loading full video Data for Whisper:** The 25 MB file size limit on Whisper API is for the preprocessed audio file, not the original video. The AudioPreprocessor outputs m4a which is much smaller.
- **Using `ObservableObject` when `@Observable` is available:** Target is iOS 17+. Use `@Observable` macro instead of `ObservableObject` + `@Published` per Apple's current recommendation. However, whozit's pattern uses `ObservableObject` — either is acceptable; be consistent within the project.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keychain CRUD | Custom Security framework wrapper | Copy KeychainService.swift from carufus_whozit | delete-then-add pattern handles update correctly; accessibility attribute set correctly |
| Silence detection | Custom audio analysis | sezit AudioPreprocessor.swift (vDSP RMS) | vDSP is hardware-accelerated; RMS threshold approach is well-validated |
| Audio speed-up with pitch preservation | Custom pitch shifting | sezit AudioPreprocessor.swift AVMutableComposition + `.timeDomain` pitch algorithm | AVMutableComposition scaleTimeRange is the Apple-blessed path; `.timeDomain` preserves pitch |
| Whisper multipart upload | Custom HTTP client | sezit WhisperAPIClient.swift | Already handles boundary, Authorization header, file type inference, error status codes |
| Network reachability | Custom socket probe | NWPathMonitor (Network framework) | NWPathMonitor is Apple's replacement for SCNetworkReachability; already in whozit as NetworkMonitor |
| File type inference for Whisper | Extension parsing | WhisperAPIClient already handles this | sezit client infers MIME from file extension |
| SwiftData migration boilerplate | Custom migration code | SchemaMigrationPlan pattern from whozit | Whozit's MigrationPlan structure is correct and minimal |

**Key insight:** This phase is primarily an assembly task — the hard parts (Keychain, audio preprocessing, Whisper API client) are already solved in production sibling code. The plan should focus on integration and adaptation, not invention.

---

## Runtime State Inventory

Step 2.5 does not apply. This is a greenfield app — no existing runtime state, stored data, or registered services. The app does not yet exist on device.

---

## Environment Availability Audit

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16 | Build + XcodeGen | Assumed — dev machine | 16.x | None — required |
| XcodeGen | project.yml scaffold | Verify before plan execution | — | Install via `brew install xcodegen` |
| Physical iOS device (iOS 17+) | IMPORT-01 video from Camera Roll, audio session validation | Assumed | — | Simulator for UI work; physical device required for PhotosPicker video + AVAudioSession validation |
| OpenAI API key | TRANS-01, TRANS-02, TRANS-03 | User provides | N/A | Graceful "no key" state; transcription disabled |
| Network connectivity | TRANS-01 Whisper API | Assumed | N/A | NWPathMonitor shows offline state; transcription button disabled |

**Missing dependencies with no fallback:**
- Xcode 16 (assumed present — dev machine has it per project context)
- Physical iOS 17+ device for AVAudioSession + PHPicker video validation

**Missing dependencies with fallback:**
- XcodeGen not confirmed installed; `brew install xcodegen` is a one-line fix if absent
- OpenAI API key — app gracefully handles absence per D-13

---

## Common Pitfalls

### Pitfall 1: PHPickerViewController Temporary URL Invalidated Before Copy

**What goes wrong:** `loadFileRepresentation(forTypeIdentifier:)` provides a temporary URL in a sandbox-restricted location. If the callback returns before the file is copied, the URL is invalidated. This silently produces an empty file on disk.

**Why it happens:** The temporary URL's lifecycle is scoped to the callback. File access must complete synchronously or via an explicit security-scope bookmark within the callback.

**How to avoid:** Copy the file to the app's Documents sandbox inside the `loadFileRepresentation` callback, before the callback returns. Do not pass the URL out of the callback without first copying.

**Warning signs:** Imported video file exists in sandbox but has 0 bytes. VideoPlayer shows blank frame.

---

### Pitfall 2: Whisper API 25 MB File Size Limit

**What goes wrong:** A long video (10+ min at high quality) produces an audio extraction > 25 MB. The Whisper API returns HTTP 413.

**Why it happens:** Audio extraction from high-quality video produces large m4a files before preprocessing. The preprocessing (silence removal + 1.5x speedup) reduces size but may not be sufficient for very long content.

**How to avoid:** After AVAssetExportSession and before calling WhisperAPIClient, check file size:
```swift
let attributes = try FileManager.default.attributesOfItem(atPath: processedURL.path)
let fileSize = attributes[.size] as? Int ?? 0
guard fileSize < 25_000_000 else {
    throw TranscriptionError.fileTooLarge
}
```
Surface a user-visible error: "Audio too long for transcription. Try content under 15 minutes."

**Warning signs:** HTTP 413 from Whisper API. Large reference videos that fail silently.

---

### Pitfall 3: SwiftData @Model Class Cannot Be `struct`

**What goes wrong:** Developer defines `ReferenceContent` as a `struct` (more natural in Swift). Compiler error or crash at runtime.

**Why it happens:** SwiftData `@Model` requires a `class` (reference type) because the persistence layer uses object identity.

**How to avoid:** Always declare SwiftData models as `final class`. The `@Model` macro does not work on structs.

---

### Pitfall 4: AVAssetExportSession Not Awaitable in Older Pattern

**What goes wrong:** `exportSession.export()` is called using the completion handler form. In Swift 6 strict concurrency mode, passing the session across actor boundaries with a callback causes a warning or error.

**Why it happens:** The async form `await exportSession.export()` was added in iOS 16+. The sezit AudioPreprocessor.swift already uses `await exportSession.export()` — confirm you're using the async form, not the completion handler form.

**How to avoid:** Use `await exportSession.export()` (iOS 16+ async method). This is already the pattern in sezit's AudioPreprocessor.

---

### Pitfall 5: Security-Scoped URL Not Released After Audio Import

**What goes wrong:** After calling `startAccessingSecurityScopedResource()` on the URL from `.fileImporter`, the resource lock is never released. The Files app may show the file as "in use". On repeat imports, the system runs out of security-scoped access handles.

**Why it happens:** Forgetting `stopAccessingSecurityScopedResource()` after file copy completes.

**How to avoid:** Always use `defer { url.stopAccessingSecurityScopedResource() }` immediately after `startAccessingSecurityScopedResource()` succeeds. This guarantees release regardless of error path.

---

### Pitfall 6: `automaticallyConfiguresApplicationAudioSession` Default = true

**What goes wrong:** AVCaptureSession is configured in Phase 2 and automatically reconfigures the audio session, dropping the `.allowBluetoothA2DP` and `.defaultToSpeaker` options set in Phase 1's AudioSessionManager.configure().

**Why it happens:** `AVCaptureSession.automaticallyConfiguresApplicationAudioSession` defaults to `true`. This is a Phase 2 concern but must be remembered when CaptureEngine is built.

**How to avoid:** Document explicitly in CaptureEngine init: `captureSession.automaticallyConfiguresApplicationAudioSession = false`. Add this as a MUST-DO note in Phase 2 planning. The ARCHITECTURE.md already calls this out as Anti-Pattern 1.

---

### Pitfall 7: WhisperAPIClient Sends Wrong Content-Type for .mp4 Audio

**What goes wrong:** If the audio extracted from a video is saved as .mp4 extension (not .m4a), the multipart body may set `Content-Type: audio/mp4` but Whisper expects `audio/m4a` or the correct MIME type. Some builds return 400.

**Why it happens:** AVAssetExportSession with `presetName: AVAssetExportPresetAppleM4A` outputs .m4a. But if the output URL extension is accidentally set to .mp4, the MIME type inference fails.

**How to avoid:** Always use `.appendingPathExtension("m4a")` on the temp URL when extracting audio for transcription.

---

## Code Examples

### KeychainService — Copy with Service Change
```swift
// Services/KeychainService.swift
// Source: ../carufus_whozit/Whozit/Services/KeychainService.swift
// Change: service identifier only

enum KeychainService {
    private static let service = "com.okmango.mimzit"  // <-- changed

    static func save(key: String, value: String) throws {
        let data = Data(value.utf8)
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }
    // load() and delete() unchanged
}
```

### AudioPreprocessor — Copy Verbatim
```swift
// Services/AudioPreprocessor.swift
// Source: ../sezit/Sezit/Services/AudioPreprocessor.swift
// No changes required. silenceThreshold: 0.01, speedMultiplier: 1.5
// Uses AVAudioFile + vDSP (silence removal) + AVMutableComposition (speedup)
// Both stages already async-safe
```

### WhisperAPIClient — Minimal Adaptation
```swift
// Services/WhisperAPIClient.swift
// Source: ../sezit/Sezit/Services/WhisperAPIClient.swift
// Changes:
//   1. No changes needed to core transcription logic
//   2. The client already accepts audioFileURL: URL — matches our audio extraction output
//   3. WhisperError enum is complete and production-grade (handles 401, 429, 5xx)
//   4. Boundary/multipart implementation is correct
```

### NetworkMonitor — Extract from whozit TranscriptionService
```swift
// Services/NetworkMonitor.swift
// Source: last ~25 lines of ../carufus_whozit/Whozit/Services/TranscriptionService.swift
// The NetworkMonitor class is embedded at the bottom of TranscriptionService.swift
// Extract it to its own file. No changes required.

import Network

final class NetworkMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.okmango.mimzit.network")
    private let lock = NSLock()
    private var _isConnected: Bool = true

    var isConnected: Bool { lock.withLock { _isConnected } }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.withLock { self._isConnected = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }
    deinit { monitor.cancel() }
}
```

### SettingsView — API Key Section (whozit pattern)
```swift
// Features/Settings/SettingsView.swift
// The API key section from whozit SettingsView maps directly:
//   openAIService.isConfigured → configured state (checkmark + clear button)
//   !openAIService.isConfigured → entry state (SecureField + eye toggle + Save)
// Whozit uses @ObservedObject var openAIService = OpenAIService.shared
// For Mimzit: same pattern but service is MimzitOpenAIService (or just reuse same name)
// Key insight: the "configured" vs "unconfigured" dual-state Section is the pattern to copy
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIImagePickerController | PhotosUI.PhotosPicker | iOS 14 (deprecated), iOS 16 (SwiftUI native) | Must not use UIImagePickerController — App Store flags it |
| CoreData + NSPersistentContainer | SwiftData @Model + ModelContainer | iOS 17 | SwiftData eliminates boilerplate; migration plan required from day 1 |
| SCNetworkReachability | NWPathMonitor (Network.framework) | iOS 12 | NWPathMonitor is the current Apple-blessed approach |
| Combine @Published reactive chains | Swift Concurrency async/await | Swift 5.5 / iOS 15 | AVFoundation notifications still use NotificationCenter; use async/await for all service calls |
| `exportSession.export(completionHandler:)` | `await exportSession.export()` | iOS 16 | Async form available; sezit already uses it |
| ObservableObject + @Published | @Observable macro | iOS 17 | Target is iOS 17+; @Observable reduces boilerplate. Either works — be consistent |
| `AVAudioApplication.requestRecordPermission` | Use `AVCaptureDevice.requestAccess(for: .audio)` for capture sessions | iOS 17 | For AVCaptureSession, use AVCaptureDevice.requestAccess. For pure audio recording, AVAudioApplication.requestRecordPermission. Whozit's AudioRecorderService uses the latter correctly. |

**Deprecated/outdated:**
- `UIImagePickerController`: Deprecated iOS 14. Use PhotosPicker.
- `SFSpeechRecognizer` fallback: Deferred per D-11. Do not implement in Phase 1.
- `PHPhotoLibrary.requestAuthorization`: Not needed for PhotosPicker read-only access on iOS 16+.

---

## Open Questions

1. **ContentView navigation structure: TabView vs NavigationStack**
   - What we know: Whozit uses TabView (Contacts, Locations, Tags, Settings). Mimzit is simpler — likely just Content Library + Settings.
   - What's unclear: Whether a 2-tab structure or a NavigationStack with a Settings gear button is cleaner for Mimzit's simpler feature set.
   - Recommendation: Use `NavigationStack` with a toolbar gear button for Settings. No TabView needed in Phase 1 — there's only one primary screen (content library). A TabView can be added in Phase 3 if Session History justifies it.

2. **Video thumbnail generation for content library rows**
   - What we know: IMPORT-04 stores a `thumbnailFilename`. The ReferenceContent model has `thumbnailFilename: String?`.
   - What's unclear: Whether thumbnail generation (via `AVAssetImageGenerator`) should happen during import or lazily on display.
   - Recommendation: Generate on import using `AVAssetImageGenerator.generateCGImageAsynchronously`. Store as JPEG in Documents/content/. This is cleaner than on-demand generation in list cells.

3. **`@Observable` vs `ObservableObject` consistency**
   - What we know: iOS 17+ target allows `@Observable`. whozit uses `ObservableObject` (older pattern but stable). sezit uses `ObservableObject`.
   - What's unclear: Whether to modernize to `@Observable` for Mimzit or match sibling project patterns.
   - Recommendation: Use `@Observable` for new Mimzit services. It's the current Apple recommendation for iOS 17+ greenfield apps. The sibling projects won't be affected.

---

## Project Constraints (from CLAUDE.md)

| Directive | Source | Impact on Phase 1 |
|-----------|--------|-------------------|
| iOS only (iPhone), minimum iOS 16+ | CLAUDE.md Constraints | project.yml targets iOS 17+ (SwiftData). TARGETED_DEVICE_FAMILY: "1" (iPhone only) |
| mp4/mov only for video | CLAUDE.md Constraints | PhotosPicker filter: `.videos` returns all video; filter to mp4/mov by UTType after selection or show warning |
| All data local on-device | CLAUDE.md Constraints | No CloudKit, no iCloud Drive. FileManager Documents only. |
| Camera + microphone access required | CLAUDE.md Constraints | Info.plist keys in project.yml. Permission requests lazy (Phase 2 for camera; never for Phase 1) |
| No copyrighted content distribution | CLAUDE.md Constraints | App does not distribute content; user imports their own. No impact on Phase 1 |
| AVFoundation only (no VLCKit etc.) | CLAUDE.md Stack | VideoPlayer (AVKit) for preview is acceptable; AVPlayerLayer for recording screen (Phase 2) |
| No AVKit VideoPlayer for recording screen | CLAUDE.md What NOT to Use | Recording screen is Phase 2. Phase 1 preview uses AVKit VideoPlayer (correct for preview-only) |
| No UIImagePickerController | CLAUDE.md What NOT to Use | PhotosPicker used exclusively. Covered. |
| FileManager for video storage; SwiftData for paths only | CLAUDE.md Stack | SwiftData model stores relative filename strings. FileVault resolves URLs. |
| SwiftData for session metadata; FileManager for binary | CLAUDE.md Stack | ReferenceContent model: String filenames + metadata only. No video bytes in SwiftData. |
| XcodeGen (project.yml) | CONTEXT.md D-01 | project.yml scaffold is Wave 0 task |
| @MainActor + ObservableObject for services | CONTEXT.md Established Patterns | Use @MainActor on service classes. @Observable also acceptable for iOS 17+ greenfield. |

---

## Sources

### Primary (HIGH confidence)
- `../carufus_whozit/Whozit/Services/KeychainService.swift` — direct copy source, read in full
- `../carufus_whozit/Whozit/Services/TranscriptionService.swift` — NetworkMonitor extract source; Whisper+Speech pattern reference; read in full
- `../carufus_whozit/Whozit/App/WhozitApp.swift` — ModelContainer + migration plan entry point pattern; read in full
- `../carufus_whozit/Whozit/Features/Settings/SettingsView.swift` — API key entry/configured dual-state pattern; read in full
- `../carufus_whozit/Whozit/Services/OpenAIService.swift` — isConfigured pattern, setAPIKey/clearAPIKey; read in full
- `../sezit/Sezit/Services/WhisperAPIClient.swift` — direct copy source; multipart upload; read in full
- `../sezit/Sezit/Services/AudioPreprocessor.swift` — direct copy source; vDSP + AVMutableComposition; read in full
- `../carufus_whozit/project.yml` — XcodeGen pattern reference; read in full
- `../sezit/project.yml` — XcodeGen iOS 17 target pattern; read in full
- `.planning/research/ARCHITECTURE.md` — AudioSessionManager pattern, FileVault pattern, anti-patterns; full project research
- `.planning/research/STACK.md` — Technology decisions with rationale
- `.planning/phases/01-foundation-import-transcription/01-CONTEXT.md` — all implementation decisions D-01 through D-15

### Secondary (MEDIUM confidence)
- Apple Developer Documentation: AVAudioSession.routeChangeNotification — headphone detection pattern
- Apple Developer Documentation: PHPickerViewController — PhotosPicker behavior on iOS 16+
- Apple Developer Documentation: AVAssetExportSession — async export pattern
- CLAUDE.md — full project constraints and stack decisions

### Tertiary (LOW confidence)
- Whisper API 25 MB file size limit — documented at platform.openai.com/docs; not directly verified via fetch but well-established community knowledge and consistent with sezit's preprocessing rationale

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple system frameworks; sibling code read directly
- Architecture patterns: HIGH — based on whozit/sezit production code + ARCHITECTURE.md research
- Code examples: HIGH — directly adapted from production sibling code
- Pitfalls: HIGH (most verified against actual code paths) / MEDIUM (Whisper 25MB limit is community-confirmed)

**Research date:** 2026-03-25
**Valid until:** Stable — Apple system frameworks; 90 days. Whisper API behavior — 30 days (API may change).
