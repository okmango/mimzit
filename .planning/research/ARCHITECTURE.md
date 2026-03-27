# Architecture Research

**Domain:** Native iOS speech shadowing app — simultaneous video playback + camera recording with blended overlay UI
**Researched:** 2026-03-25
**Confidence:** HIGH (core AVFoundation constraints from official Apple docs and forums; pattern choices from verified iOS architecture sources)

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SwiftUI Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  ImportView  │  │  SessionView │  │  ReviewView  │              │
│  │  (PHPicker) │  │  (record UI) │  │  (playback)  │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                 │                       │
├─────────┴─────────────────┴─────────────────┴───────────────────────┤
│                     ViewModel / Service Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  ImportVM    │  │  SessionVM   │  │  ReviewVM    │              │
│  │ (@Observable)│  │ (@Observable)│  │ (@Observable)│              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                 │                       │
├─────────┴─────────────────┴─────────────────┴───────────────────────┤
│                      AVFoundation Engine Layer                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   AudioSessionManager                         │  │
│  │  (AVAudioSession.sharedInstance — configured once, app-wide) │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│  ┌──────────────────┐       │       ┌──────────────────────────┐    │
│  │  PlaybackEngine  │       │       │    CaptureEngine         │    │
│  │  (AVPlayer +     │◄──────┴──────►│  (AVCaptureSession +    │    │
│  │  AVPlayerLayer)  │  shared audio │  AVCaptureMovieFileOut) │    │
│  └──────────────────┘               └──────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    CompositorLayer                           │   │
│  │  (CALayer tree: AVPlayerLayer + AVCaptureVideoPreviewLayer) │   │
│  │   opacity controlled by DJ-fader slider value               │   │
│  └──────────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────────────┤
│                        Persistence Layer                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐ │
│  │   SessionStore   │  │  FileVault       │  │  SwiftData Model   │ │
│  │ (CRUD, query)    │  │ (FileManager,    │  │  (PracticeSession) │ │
│  │                  │  │  Documents dir)  │  │                    │ │
│  └──────────────────┘  └──────────────────┘  └────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| AudioSessionManager | Configure AVAudioSession once at app launch; handle route changes (headphone insert/remove); handle interruptions | Singleton Swift class; listens for `AVAudioSession.routeChangeNotification` and `AVAudioSession.interruptionNotification` |
| PlaybackEngine | Load reference video into AVPlayer; expose AVPlayerLayer for display; control play/pause/seek; expose volume property for audio fader | `@Observable` class wrapping `AVPlayer` + `AVPlayerLayer`; `AVPlayerItem` KVO for status |
| CaptureEngine | Configure `AVCaptureSession` with front camera (`AVCaptureDevice`) + microphone input + `AVCaptureMovieFileOutput`; expose `AVCaptureVideoPreviewLayer` for display | `@Observable` class; session lifecycle on dedicated serial DispatchQueue |
| CompositorLayer | Stack `AVPlayerLayer` (bottom) and `AVCaptureVideoPreviewLayer` (top) in a single `UIView`; expose `overlayOpacity: Float` property that maps fader slider → `AVCaptureVideoPreviewLayer.opacity` | `UIViewRepresentable` wrapping a `UIView`; CALayer hierarchy managed imperatively |
| AudioMixer | Map audio fader slider value → `AVPlayer.volume` (0.0–1.0) for reference audio level; user mic audio stays at capture default and is baked into the recording | Pure value mapping in SessionVM; no separate class needed at MVP |
| ImportCoordinator | Wrap `PHPickerViewController` for video selection from Photo Library; validate format (mp4/mov); copy asset to app Documents sandbox | `UIViewControllerRepresentable`; uses `PHPickerConfiguration` with video filter |
| SessionStore | Persist `PracticeSession` metadata (timestamp, reference video filename, recording filename, duration); query sessions for history list | SwiftData `@Model` class; `ModelContainer` configured at app level |
| FileVault | Own app file I/O for video files: write recording output to `Documents/recordings/`, read reference/recording URLs for playback | Thin wrapper around `FileManager`; supplies `URL` values to AVFoundation objects |
| ReviewVM | Reconstruct PlaybackEngine × 2 (one per video) using stored file URLs; drive same CompositorLayer and fader controls; no CaptureEngine involved | Reuses same component contracts; deactivates capture pathway |

---

## Recommended Project Structure

```
Mimzit/
├── App/
│   ├── MimzitApp.swift          # @main, ModelContainer setup, AudioSessionManager init
│   └── AppCoordinator.swift      # Top-level navigation state
├── Features/
│   ├── Import/
│   │   ├── ImportView.swift
│   │   ├── ImportViewModel.swift
│   │   └── VideoPicker.swift     # UIViewControllerRepresentable (PHPicker)
│   ├── Session/
│   │   ├── SessionView.swift     # Live record screen
│   │   ├── SessionViewModel.swift
│   │   └── FaderControlView.swift # DJ-fader slider UI component
│   ├── Review/
│   │   ├── ReviewView.swift
│   │   └── ReviewViewModel.swift
│   └── History/
│       ├── HistoryView.swift
│       └── HistoryViewModel.swift
├── Engines/
│   ├── AudioSessionManager.swift  # Singleton; AVAudioSession config
│   ├── PlaybackEngine.swift       # AVPlayer + AVPlayerLayer
│   ├── CaptureEngine.swift        # AVCaptureSession + movie output
│   └── CompositorView.swift       # UIViewRepresentable; CALayer stack
├── Persistence/
│   ├── Models/
│   │   └── PracticeSession.swift  # SwiftData @Model
│   ├── SessionStore.swift         # SwiftData CRUD wrapper
│   └── FileVault.swift            # FileManager video I/O
└── Utilities/
    ├── Extensions/
    └── Constants.swift
```

### Structure Rationale

- **Engines/:** AVFoundation objects are UIKit-imperative by nature; isolating them here prevents media lifecycle from leaking into SwiftUI views or SwiftData models.
- **Features/:** Screen-level grouping matches navigation structure — each feature folder is a self-contained unit with its own VM.
- **Persistence/:** SwiftData model and FileManager operations separated from engine layer; session metadata and video bytes have different lifecycles (SwiftData handles metadata, FileVault owns raw file paths).

---

## Architectural Patterns

### Pattern 1: Single AVAudioSession, Configured Before Any Engine Starts

**What:** `AVAudioSession.sharedInstance()` is a process-wide singleton. Configure category, mode, and options exactly once — before either `AVPlayer` or `AVCaptureSession` is started — and never let `AVCaptureSession` reconfigure it automatically.

**When to use:** Always, for this app. This is not optional — incorrect sequencing causes audio to silently fail or route incorrectly.

**Configuration:**
```swift
// AudioSessionManager.configure() — called at app launch, before any engine
let session = AVAudioSession.sharedInstance()
try session.setCategory(
    .playAndRecord,
    mode: .default,
    options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
)
try session.setActive(true)
```

Then on `AVCaptureSession`:
```swift
captureSession.automaticallyConfiguresApplicationAudioSession = false
```

This prevents `AVCaptureSession` from overriding the session configured above.

**Trade-offs:** One configuration to maintain; but you must handle route-change notifications yourself (headphone insert/remove). Without `.allowBluetooth`, AirPods will not appear as input routes. Without `.allowBluetoothA2DP`, A2DP high-quality output is suppressed when in `.playAndRecord` category.

---

### Pattern 2: CALayer Stack for Real-Time Video Blend (Fader)

**What:** The visual DJ-fader is implemented as a CALayer opacity change on the top layer, not a video compositor or AVMutableVideoComposition. Two `CALayer` subclasses — `AVPlayerLayer` (reference video, bottom) and `AVCaptureVideoPreviewLayer` (camera, top) — are stacked in a single `UIView`. The fader slider updates `previewLayer.opacity` on the main thread.

**When to use:** Live blending during record and review. This is the correct approach for real-time display; `AVMutableVideoComposition` is for export/render pipelines, not live preview.

**Example:**
```swift
// CompositorView (UIViewRepresentable backing UIView)
func layout(playerLayer: AVPlayerLayer, previewLayer: AVCaptureVideoPreviewLayer) {
    playerLayer.frame = bounds
    previewLayer.frame = bounds
    layer.addSublayer(playerLayer)
    layer.addSublayer(previewLayer)
}

// Fader slider action (called on main thread)
func setVideoBlend(_ value: Float) {
    // value: 0.0 = reference only, 1.0 = camera only
    previewLayer.opacity = value
}
```

**Trade-offs:** Extremely low overhead (GPU compositing). The limitation is that opacity blend is additive/alpha — both layers are visible at any opacity > 0 for the top layer. This is correct behavior for the DJ-fader concept. No frame-level pixel access is needed.

---

### Pattern 3: CaptureEngine on Dedicated Serial Queue

**What:** All `AVCaptureSession` configuration and lifecycle calls (`startRunning`, `stopRunning`, `beginConfiguration`, `commitConfiguration`) must happen off the main thread on a dedicated serial `DispatchQueue`. UI updates must be marshalled back to main.

**When to use:** Always. `AVCaptureSession.startRunning()` is synchronous and blocks the calling thread while the camera hardware initializes — calling it on the main thread freezes the UI.

**Example:**
```swift
class CaptureEngine {
    private let sessionQueue = DispatchQueue(label: "com.mimzit.capture", qos: .userInitiated)

    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}
```

**Trade-offs:** Requires consistent discipline about which operations happen on `sessionQueue` vs main thread; mixing queues causes crashes or undefined behavior.

---

### Pattern 4: AVCaptureMovieFileOutput for MVP Recording

**What:** Use `AVCaptureMovieFileOutput` (not `AVAssetWriter`) for capturing the user's camera recording. It handles compression, container writing, and file finalization automatically.

**When to use:** MVP. The app does not need per-frame access to camera pixels; it only needs a video file written to disk.

**Trade-offs:**

| | AVCaptureMovieFileOutput | AVAssetWriter |
|---|---|---|
| Setup complexity | Low | High |
| Per-frame pixel access | No | Yes |
| Background recording | Stops on background | Can continue with entitlement |
| Pause/resume | Not supported | Supported |
| Custom encoding | No | Full control |

For MVP, `AVCaptureMovieFileOutput` is correct. If pause/resume during a session becomes a requirement, migrate to `AVAssetWriter` with `AVCaptureVideoDataOutput` + `AVCaptureAudioDataOutput`.

---

## Data Flow

### Recording Session Flow

```
User taps "Start Recording"
    │
    ▼
SessionViewModel.startSession()
    │
    ├── AudioSessionManager.configure() [if not already done]
    │
    ├── PlaybackEngine.play(url: referenceVideoURL)
    │       AVPlayer → AVPlayerLayer (renders to CompositorView bottom layer)
    │       AVPlayer.volume set by audio fader state
    │
    ├── CaptureEngine.startRecording(outputURL: recordingURL)
    │       sessionQueue.async:
    │           AVCaptureSession.startRunning()
    │           AVCaptureMovieFileOutput.startRecording(to: outputURL, ...)
    │       AVCaptureVideoPreviewLayer renders to CompositorView top layer
    │
    └── FaderControlView binds slider → SessionViewModel
            videoBlend: Float → CompositorView.setVideoBlend(_:)   [opacity on previewLayer]
            audioBlend: Float → PlaybackEngine.player.volume        [0.0–1.0]

User taps "Stop"
    │
    ▼
CaptureEngine.stopRecording()
    └── AVCaptureMovieFileOutput.stopRecording()
        └── delegate callback: fileOutput(_:didFinishRecordingTo:from:error:)
            └── SessionViewModel receives outputURL
                └── SessionStore.save(PracticeSession(
                        referenceURL: referenceVideoURL,
                        recordingURL: outputURL,
                        createdAt: Date(),
                        duration: ...
                    ))
```

### Review Playback Flow

```
User selects session from HistoryView
    │
    ▼
ReviewViewModel.load(session: PracticeSession)
    │
    ├── PlaybackEngine A ← session.referenceURL  (bottom layer)
    └── PlaybackEngine B ← session.recordingURL  (top layer)
            Both AVPlayers driven by same CMTime clock
            (AVPlayer does not natively sync two players — use periodic time observer
             on one player to seek the other within ±0.1s tolerance)

FaderControlView (same component, same bindings)
    videoBlend → ReviewCompositorView.setVideoBlend(_:)   [opacity on top PlayerLayer]
    audioBlend → playerA.volume / playerB.volume          [cross-fade: vol_A = 1-x, vol_B = x]
```

### Persistence Data Flow

```
PracticeSession (SwiftData @Model)
    ├── id: UUID
    ├── createdAt: Date
    ├── duration: TimeInterval
    ├── referenceFilename: String     (relative to Documents/)
    └── recordingFilename: String     (relative to Documents/)

FileVault resolves absolute URLs at runtime:
    FileManager.default.urls(for: .documentDirectory)[0]
        .appendingPathComponent(session.recordingFilename)

No absolute paths stored — relative filenames survive app reinstall if backup is preserved.
```

### Audio Routing Flow

```
AVAudioSession (.playAndRecord, [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
    │
    ├── Output route (detected at runtime):
    │       Wired headphones  → reference audio → headphones
    │       AirPods (A2DP)    → reference audio → AirPods
    │       No headphones     → reference audio → speaker (defaultToSpeaker)
    │
    └── Input route:
            AVCaptureSession picks up built-in microphone by default
            (mic captures user's voice; headphones/AirPods provide reference audio isolation)

Route change handling (AVAudioSession.routeChangeNotification):
    → Headphones unplugged mid-session → pause session, show alert, re-route to speaker
```

---

## Component Boundaries

| Boundary | Communication | Rule |
|----------|---------------|------|
| SwiftUI View ↔ ViewModel | `@Observable` property binding, method calls | Views never touch AVFoundation directly |
| ViewModel ↔ Engine | Method calls + async callbacks | VMs own engines; engines do not hold VM references |
| CaptureEngine ↔ PlaybackEngine | No direct communication | Coordinated by SessionViewModel |
| AudioSessionManager ↔ Engines | Shared singleton; engines check session state | AudioSessionManager configures; engines do not call `setCategory` |
| CompositorView ↔ Engines | Engines expose `AVPlayerLayer` / `AVCaptureVideoPreviewLayer`; CompositorView adds them as sublayers | Layers injected into CompositorView at setup; no circular refs |
| SessionViewModel ↔ SessionStore | Method calls (save, fetch, delete) | SessionStore is pure persistence; no AVFoundation dependencies |
| SessionStore ↔ FileVault | SessionStore holds filenames; FileVault resolves URLs | FileVault is the only component that calls `FileManager` |

---

## Suggested Build Order

Dependencies flow bottom-up. Build the foundation before the features that depend on it.

```
Phase 1 — Foundation (no UI needed to validate)
    AudioSessionManager           ← everything else depends on audio session correctness
    FileVault                     ← persistence layer needs file I/O before session metadata
    SwiftData PracticeSession model + SessionStore

Phase 2 — Playback Engine
    PlaybackEngine (AVPlayer + AVPlayerLayer)
    CompositorView (UIViewRepresentable, single layer for now)
    ImportCoordinator (PHPicker → copy file → Documents/)
    ImportView + ImportViewModel

Phase 3 — Capture Engine
    CaptureEngine (AVCaptureSession + AVCaptureMovieFileOutput)
    CompositorView updated to stack two layers (PlayerLayer + PreviewLayer)
    SessionView + SessionViewModel (wires playback + capture together)
    FaderControlView (video opacity + audio volume)

Phase 4 — Persistence + History
    Session save on recording stop (SessionStore.save)
    HistoryView + HistoryViewModel
    Session deletion + file cleanup in FileVault

Phase 5 — Review
    ReviewViewModel (two PlaybackEngines from stored URLs)
    ReviewView (same CompositorView + FaderControlView reused)
    Dual-player time sync (periodic observer pattern)

Phase 6 — Audio Routing + Edge Cases
    Route change handling in AudioSessionManager
    Background interruption handling
    Permission denied states (camera, microphone, photo library)
    Error states in SessionView (capture failure, disk full)
```

**Rationale for ordering:**
- AudioSessionManager must be correct before any audio/video work to avoid silent failures
- Import comes before capture because a reference video URL is required to start a session
- Session save (Phase 4) intentionally deferred from Session recording (Phase 3) so recording is shippable before history is complete
- Review (Phase 5) reuses Phase 2/3 components — no new engines needed, just wiring
- Edge cases last because they don't block the happy path

---

## Anti-Patterns

### Anti-Pattern 1: Letting AVCaptureSession Configure the Audio Session

**What people do:** Create `AVCaptureSession`, add audio input, and let `automaticallyConfiguresApplicationAudioSession = true` (the default).

**Why it's wrong:** `AVCaptureSession` will reconfigure `AVAudioSession` when it runs, overriding any `.playAndRecord` + `.allowBluetooth` options you set. This breaks headphone routing and can cause `AVPlayer` audio to be silenced or rerouted unexpectedly.

**Do this instead:** Set `captureSession.automaticallyConfiguresApplicationAudioSession = false` immediately after creating the session. Manage the audio session entirely in `AudioSessionManager`.

---

### Anti-Pattern 2: AVMutableVideoComposition for the Live Fader

**What people do:** Reach for `AVMutableVideoComposition` / `AVVideoCompositionLayerInstruction` to blend video during live preview because the API name sounds right.

**Why it's wrong:** `AVMutableVideoComposition` is a rendering pipeline for export and offline composition. It cannot drive live camera preview. It adds latency, requires `AVPlayerItem` context, and cannot consume `AVCaptureSession` output directly.

**Do this instead:** Use `CALayer.opacity` on `AVCaptureVideoPreviewLayer` for live video blend. For export (if ever needed), then use `AVMutableVideoComposition`.

---

### Anti-Pattern 3: Running AVCaptureSession on the Main Thread

**What people do:** Call `captureSession.startRunning()` on the main thread because it's inside a button tap handler.

**Why it's wrong:** `startRunning()` is synchronous and blocks while hardware initializes (can be 200–500ms). On the main thread this freezes the UI visibly.

**Do this instead:** All capture session lifecycle calls go on a dedicated `sessionQueue: DispatchQueue(label:, qos: .userInitiated)`. UI state changes (published properties) are dispatched back to `DispatchQueue.main`.

---

### Anti-Pattern 4: Storing Absolute File Paths in SwiftData

**What people do:** Store the full `URL.path` string (e.g., `/var/mobile/Containers/Data/Application/UUID/Documents/...`) as the video file reference in the database.

**Why it's wrong:** The app container UUID changes on reinstall. Stored absolute paths become invalid. This is a silent failure — the file still exists, but the path is wrong.

**Do this instead:** Store only the filename or path relative to the Documents directory. Reconstruct the full URL at runtime by combining `FileManager.default.urls(for: .documentDirectory)` + the stored relative path.

---

### Anti-Pattern 5: Two Separate AVAudioSessions for Playback and Capture

**What people do:** Create separate audio session configurations for AVPlayer and AVCaptureSession thinking each needs its own setup.

**Why it's wrong:** `AVAudioSession.sharedInstance()` is process-wide. There is only one audio session per app. Multiple configuration calls conflict; only the last one wins.

**Do this instead:** Configure the shared audio session once, before either engine starts, with options that satisfy both: `.playAndRecord` with `.allowBluetooth` and `.allowBluetoothA2DP`.

---

## Scaling Considerations

This is a single-user, local-only app. Traditional user-scale concerns don't apply. "Scaling" here means device resource usage.

| Concern | At MVP | If Features Expand |
|---------|--------|-------------------|
| Disk usage (2–10 min sessions) | ~200–500 MB per session pair at default capture quality; warn user when < 500 MB free | Add session export/delete, quality selector, storage usage indicator |
| Memory (two video layers) | AVPlayerLayer + AVCaptureVideoPreviewLayer share GPU compositor; low CPU impact | If adding filters or frame processing, switch CaptureEngine to AVAssetWriter + VideoDataOutput |
| Session history list | SwiftData with 50–200 sessions trivially fast; no pagination needed | Add search/filter if > 500 sessions becomes realistic |
| Review dual-player sync | Periodic time observer at 0.1s granularity is fine; < 1ms overhead | AVSynchronizedLayer if tighter sync is needed (unlikely for speech shadowing) |

---

## Integration Points

### Internal Boundaries (Component ↔ Component)

| Boundary | Communication Method | Notes |
|----------|----------------------|-------|
| SessionViewModel ↔ PlaybackEngine | Direct method calls; `@Observable` published state | VM owns engine; engine lifecycle tied to VM lifetime |
| SessionViewModel ↔ CaptureEngine | Direct method calls on `sessionQueue`; delegate callbacks → `@MainActor` | Delegate pattern for file output completion |
| SwiftUI FaderControlView ↔ SessionVM | SwiftUI `Binding<Float>` | Slider value drives both `PlaybackEngine.volume` and `CompositorView.opacity` |
| CompositorView ↔ PlaybackEngine | `AVPlayerLayer` passed at init | Layer is inserted into UIView hierarchy; engine retains player reference |
| CompositorView ↔ CaptureEngine | `AVCaptureVideoPreviewLayer` passed at init | Layer is inserted above PlayerLayer; session retained by engine |
| ReviewViewModel ↔ SessionStore | `PracticeSession` model object passed at navigation | SwiftData model is the data contract across the boundary |

### External System Integration

| System | Integration Pattern | Notes |
|--------|---------------------|-------|
| Photo Library (PHPhotoLibrary) | `PHPickerViewController` via `UIViewControllerRepresentable` | Request `.readWrite` access only if saving back; `.addOnly` not needed. For import-only, `PHPicker` does not require photo library permission on iOS 16+ |
| Camera hardware | `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)` | Request `AVCaptureDevice.authorizationStatus(for: .video)` permission before configuring session |
| Microphone hardware | Added as `AVCaptureDeviceInput` to `AVCaptureSession` | Permission covered by `AVCaptureSession` microphone usage; request `AVCaptureDevice.authorizationStatus(for: .audio)` |
| AirPods / wired headphones | `AVAudioSession` route management; `routeChangeNotification` observer | No direct hardware API; all mediated through `AVAudioSession` output route |

---

## Sources

- [AVCaptureSession — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturesession)
- [AVCaptureVideoPreviewLayer — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer)
- [AVPlayerLayer — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avplayerlayer)
- [playAndRecord category — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avaudiosession/category/1616568-playandrecord)
- [allowBluetooth — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions/1616518-allowbluetooth)
- [CALayer opacity — Apple Developer Documentation](https://developer.apple.com/documentation/quartzcore/calayer/1410933-opacity)
- [AVCaptureMultiCamSession — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession)
- [WWDC19: Introducing Multi-Camera Capture for iOS](https://developer.apple.com/videos/play/wwdc2019/249/)
- [WWDC25: Enhance your app's audio recording capabilities](https://developer.apple.com/videos/play/wwdc2025/251/)
- [Capturing Video on iOS — objc.io](https://www.objc.io/issues/23-video/capturing-video/)
- [AVCaptureMovieFileOutput vs AVAssetWriter — Tinyfool's blog](https://tinyfool.org/2023/06/146/)
- [Handling Audio Sessions with Bluetooth in Swift — Atomic Object](https://spin.atomicobject.com/bluetooth-audio-sessions-swift/)
- [Building a Camera App With SwiftUI and Combine — Kodeco](https://www.kodeco.com/26244793-building-a-camera-app-with-swiftui-and-combine)
- [SwiftData for Local Persistence 2025 — Medium](https://medium.com/@koteshpatel6/using-swiftdata-for-local-persistence-replacing-core-data-in-2025-3c8c50235467)
- [AVFoundation Tutorial: Adding Overlays and Animations to Videos — Kodeco](https://www.kodeco.com/6236502-avfoundation-tutorial-adding-overlays-and-animations-to-videos)

---

*Architecture research for: iOS speech shadowing app (Mimzit) — simultaneous video playback + camera recording*
*Researched: 2026-03-25*
