# Stack Research

**Domain:** Native iOS video capture + playback comparison app
**Researched:** 2026-03-25
**Confidence:** HIGH (Apple frameworks) / MEDIUM (composition approach) / LOW (noted where applicable)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 5.10+ (Xcode 16) | Primary language | The only modern choice for new iOS development; ARC, concurrency model, and async/await make AVFoundation integration cleaner than Objective-C |
| SwiftUI | iOS 16+ | UI layer | Project already targets iOS 16+; SwiftUI handles all non-video UI natively. Video layers require UIViewRepresentable bridges — this is expected, not a weakness |
| AVFoundation | iOS 16+ | All camera, playback, capture, and composition work | Apple's only first-party media framework; no third-party library gets near its hardware access, latency, or codec support |
| AVAudioSession | iOS 16+ | Audio session routing (playAndRecord, AirPods) | Required for simultaneous audio playback + mic recording; the `.playAndRecord` category is the only category that supports both directions without interrupting each other |
| PhotosUI (SwiftUI PhotosPicker) | iOS 16+ | Reference video import from Camera Roll | Native SwiftUI component since iOS 16; no UIViewControllerRepresentable wrapper needed; privacy-compliant out of the box |
| SwiftData | iOS 17+ | Session metadata persistence (titles, timestamps, file paths) | Project minimum is iOS 16 but SwiftData is iOS 17+. Since this is a greenfield app and iOS 18 now has 88%+ adoption, targeting iOS 17 minimum is the correct call. SwiftData integrates directly with SwiftUI @Query — zero boilerplate for session history list |
| FileManager | iOS 16+ | Video file storage and retrieval in app sandbox | Binary video files must NOT go into SwiftData; store file paths in SwiftData, raw .mov files in the app's Documents directory via FileManager |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVKit (VideoPlayer) | iOS 16+ | Simple video playback in SwiftUI where full control is not needed | Use ONLY for the session history review thumbnail previews. Do NOT use for the main recording/comparison screen — AVKit wraps AVPlayer and does not expose the layer controls needed for fader blending |
| AVMutableComposition + AVMutableVideoComposition | iOS 16+ | Post-recording composition: layering reference + user video for review playback with fader | Use for the review playback path only. Build an AVMutableComposition with two video tracks, then use AVMutableVideoCompositionLayerInstruction to set opacity per track dynamically via an AVVideoCompositionCoreAnimationTool or custom compositor |
| AVVideoCompositing (custom compositor protocol) | iOS 16+ | Real-time CPU/GPU frame blending if the fader needs sub-frame accuracy at review time | Use only if AVMutableVideoCompositionLayerInstruction opacity ramps are not smooth enough for the fader interaction. Custom compositor receives CVPixelBuffers and can blend via CoreImage or Metal. Battery-intensive — validate before committing |
| CoreImage | iOS 16+ | Pixel-level blending of two video frames in the custom compositor path | Use only inside the custom compositor if Metal is overkill. CIFilter blend modes (CIBlendWithMask, kCIBlendModeDarken, etc.) cover the fader use case with less code than Metal |
| Metal / MetalKit | iOS 16+ | GPU-accelerated blending if CoreImage is too slow | Last resort. Metal shaders can blend two CVPixelBuffers at 60fps with <1% CPU. Only reach for Metal if CoreImage benchmarks show frame drops. SwiftUI Metal layer effects (iOS 17+) work for pure UI effects but cannot consume AVFoundation pixel buffers directly |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16 | Build, simulate, profile | Use the Simulator for UI work only; AVCaptureSession requires a physical device — the simulator does not provide a real camera feed |
| Instruments (Time Profiler + Core Animation) | Profile frame drops in fader and composition pipelines | The fader interaction and live camera preview are the two highest-risk performance areas; profile early, not at the end |
| Instruments (Energy Log) | Validate battery impact of any custom compositor path | Custom AVVideoCompositing is documented by Apple as battery-intensive; measure before shipping |

---

## Architecture Notes for Video Layers

### Recording Screen: Three simultaneous layers

The recording screen requires three concurrent things:

1. **AVPlayer playing the reference video** — rendered via `AVPlayerLayer` embedded in a `UIView` wrapped with `UIViewRepresentable`. Do not use `VideoPlayer` (AVKit) here; you need direct layer access to control Z-order and opacity.

2. **AVCaptureSession front camera preview** — rendered via `AVCaptureVideoPreviewLayer` in a second `UIView` wrapped with `UIViewRepresentable`. The preview layer sits on top of or blended with the player layer.

3. **SwiftUI fader overlay** — pure SwiftUI `Slider` or custom `DragGesture`-based control drawn on top of both video layers. SwiftUI can sit above CALayer-based views in the UIView hierarchy when the UIViewRepresentable container is sized correctly.

The fader value drives two things in real-time:
- **Video blend**: Set `playerLayer.opacity` and `previewLayer.opacity` inversely proportional to the fader position. This is the cheapest path — CALayer opacity is GPU-composited by the system with no CPU work required.
- **Audio blend**: Route audio through `AVAudioSession` and control playback volume via `AVPlayer.volume` (0.0–1.0). The mic capture volume is fixed by the hardware; the blend is achieved by mixing at output (AirPods or speaker) level.

### Audio Session: Critical configuration

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(
    .playAndRecord,
    mode: .videoRecording,
    options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
)
try session.setActive(true)
```

- `.playAndRecord` is the only category that allows simultaneous mic input and audio output.
- `.allowBluetooth` enables HFP (Hands-Free Profile) for AirPods microphone input.
- `.allowBluetoothA2DP` enables higher-quality AirPods audio output.
- `.defaultToSpeaker` ensures reference audio plays through the speaker/AirPods rather than the earpiece when no headphones are connected.
- `mode: .videoRecording` tells the system to optimize for video capture (vs. `.default` which may apply noise cancellation that hurts the reference audio).
- Subscribe to `AVAudioSession.routeChangeNotification` to handle AirPods connect/disconnect gracefully.

### Review Screen: Composition approach

For the review playback screen, the recommended approach is `AVMutableComposition` with two tracks (reference + user recording), played back via a single `AVPlayer` with an `AVVideoComposition` that applies per-track opacity via `AVMutableVideoCompositionLayerInstruction.setOpacityRamp`. The fader slider directly updates the video composition's layer instructions at seek time — this does not require real-time recomposition because the opacity ramp is parameterized.

Simpler alternative for v1: Play two separate `AVPlayer` instances in the review screen (same pattern as the recording screen) and sync them by time offset. This avoids composition complexity entirely. Acceptable because review is not a live camera feed — both sources are pre-recorded files.

---

## Installation

This is a native iOS app — no package manager commands. All core technologies (AVFoundation, AVAudioSession, SwiftUI, SwiftData, PhotosUI) are Apple system frameworks included with Xcode. No SPM dependencies are required for MVP.

If the custom compositor path is chosen later, add no external dependencies — use CoreImage (system framework) first, Metal only if benchmarks demand it.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftUI + UIViewRepresentable for video layers | Full UIKit app | Only if the team has no SwiftUI experience and the entire UI needs to be UIKit. For this app, 80% of UI (history list, settings, session metadata) is pure SwiftUI — a full UIKit rewrite would add significant boilerplate for no benefit |
| SwiftData (iOS 17+) | CoreData | If the app needs iOS 16 as strict minimum. CoreData is more battle-tested and has zero performance regressions. The tradeoff: significantly more boilerplate. Given iOS 18 is at 88%+ adoption, iOS 17 minimum is justified |
| CoreData | SwiftData | Use CoreData if you encounter SwiftData crashes or migrations issues during development. CoreData is the stable foundation underneath; switching back is a 1-day refactor, not a rewrite |
| CALayer opacity for live fader blend | Custom AVVideoCompositing compositor | Use the custom compositor only for export/save of a blended video, never for live preview. Live preview using CALayer opacity is GPU-composited by the system at zero CPU cost |
| Two separate AVPlayer instances for review | AVMutableComposition single player | Use AVMutableComposition if you need to export a merged video file. For in-app review playback only, two AVPlayer instances with synchronized seek is simpler and has no offline rendering overhead |
| PhotosUI PhotosPicker (iOS 16) | UIImagePickerController | Never use UIImagePickerController for new apps — deprecated in iOS 14, removed from SwiftUI best practices. PHPickerViewController (the UIKit equivalent) is fine if you need iOS 14 support, but this project is iOS 16+ so use the native SwiftUI PhotosPicker |
| FileManager (Documents directory) | iCloud Drive / CloudKit | Out of scope for v1 per PROJECT.md. Local storage only. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| AVKit `VideoPlayer` for the recording screen | AVKit is a high-level wrapper that hides AVPlayerLayer. You cannot control Z-order, opacity, or CALayer transforms. The fader requires direct layer manipulation | `AVPlayerLayer` in a `UIViewRepresentable`-wrapped `UIView` |
| UIImagePickerController for video import | Deprecated in iOS 14, provides no privacy-aware photo library access, Apple flags apps using it in review | `PhotosUI.PhotosPicker` (SwiftUI native, iOS 16+) |
| ReplayKit | Screen recording framework — cannot capture AVPlayer video content due to DRM restrictions; also not designed for front-camera simultaneous capture | `AVCaptureSession` with `AVCaptureMovieFileOutput` |
| RxSwift / Combine-heavy reactive pipelines | Adds complexity for a single-screen recording app; AVFoundation notifications and async/await cover all the async needs | Swift Concurrency (async/await) + `NotificationCenter` for AVAudioSession route changes |
| AVAssetWriter for recording (directly) | More complex than `AVCaptureMovieFileOutput` for straightforward video-to-file recording; only reach for AVAssetWriter if you need pixel buffer access during recording (e.g., real-time watermarking) | `AVCaptureMovieFileOutput` for the user's recording to file |
| Background recording | iOS kills or suspends apps recording to file in the background; AVCaptureSession stops when app is backgrounded unless explicitly handled with a background task. Do not design the app to support backgrounding the recording — it is not needed for the use case | Foreground-only recording; handle `UIApplicationWillResignActiveNotification` to pause |
| Third-party video player libraries (e.g., VLCKit) | VLC and similar libraries add ~30MB binary size, introduce their own audio session management that conflicts with AVAudioSession, and cannot integrate with AVCaptureSession's native session. AVFoundation handles mp4/mov natively without any third-party library | `AVPlayer` with `AVFoundation` |
| SwiftData for binary video data | SwiftData (and CoreData) are not designed for binary large objects (BLOBs). Storing video bytes in the database causes severe performance issues | Store video files on disk via FileManager; store only the file path (as a String or URL) in SwiftData |

---

## Stack Patterns by Variant

**If iOS 16 strict minimum is required (not recommended but possible):**
- Drop SwiftData, use CoreData with NSPersistentContainer
- Use PhotosPicker (it is iOS 16+, no change needed)
- All AVFoundation APIs used in this app are iOS 16+ compatible

**If export / save a blended video to Camera Roll is added later:**
- Add `AVMutableComposition` + `AVAssetExportSession` path
- Use `PHPhotoLibrary.shared().performChanges` to save the exported video
- This is a post-MVP feature; do not build it in v1

**If AI speech analysis is added in a future phase:**
- `Speech.framework` (SFSpeechRecognizer) for on-device transcription — no server needed
- CoreML for custom phoneme models if needed
- Neither conflicts with the current stack

---

## Version Compatibility

| Component | Minimum iOS | Notes |
|-----------|-------------|-------|
| SwiftUI PhotosPicker | iOS 16 | Native SwiftUI component; no wrapper needed |
| SwiftData | iOS 17 | Requires bumping minimum deployment target from 16 to 17 — recommended |
| AVCaptureSession multi-output (video + movie file simultaneously) | iOS 16 | Prior to iOS 16, only one of AVCaptureVideoDataOutput or AVCaptureMovieFileOutput could be active on a session at a time — this restriction was lifted in iOS 16 |
| SwiftUI Metal layer effects (.colorEffect, .layerEffect) | iOS 17 | Only needed if going the Metal fader path; not needed for MVP |
| AVCaptureEventInteraction (hardware camera button) | iOS 26 | Future enhancement only; not relevant to MVP |

---

## Sources

- [Apple Developer: AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession) — simultaneous output restrictions lifted in iOS 16 (MEDIUM confidence — JavaScript-gated page, confirmed via search results)
- [Apple Developer: AVMutableVideoCompositionLayerInstruction](https://developer.apple.com/documentation/avfoundation/avmutablevideocompositionlayerinstruction) — opacity ramp API for review composition (HIGH confidence — official docs)
- [Apple Developer: AVAudioSession responding to route changes](https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_route_changes) — AirPods routing behavior (HIGH confidence — official docs)
- [TelemetryDeck iOS Version Market Share 2026](https://telemetrydeck.com/survey/apple/iOS/majorSystemVersions/) — iOS 18 at 88%+ adoption, iOS 16 minimum reaches ~96% of devices (HIGH confidence)
- [SwiftData vs Core Data 2025 — byby.dev](https://byby.dev/swiftdata-or-coredata) — SwiftData recommendation for greenfield iOS 17+ projects (MEDIUM confidence — community analysis)
- [WWDC 2025: Enhancing your camera experience with capture controls](https://developer.apple.com/videos/play/wwdc2025/253/) — AVCaptureEventInteraction in iOS 26, context for future-proofing (HIGH confidence — official Apple session)
- [banuba.com: AVFoundation PiP mode overlay](https://www.banuba.com/blog/how-to-implement-an-overlay-video-editor-picture-in-picture-mode-for-ios-with-avfoundation) — AVMutableComposition overlay pattern confirmation (MEDIUM confidence)
- [Apple PhotosUI PhotosPicker SwiftUI](https://developer.apple.com/documentation/PhotosUI/PHPickerViewController) — native iOS 16 SwiftUI picker (HIGH confidence — official docs)
- [Simform: AVAudioSession input device management](https://medium.com/simform-engineering/audio-input-device-switch-management-in-avaudiosession-4a7c4dd78eb5) — playAndRecord + Bluetooth options (MEDIUM confidence)

---

*Stack research for: Spikzit — native iOS speech shadowing app with video comparison*
*Researched: 2026-03-25*
