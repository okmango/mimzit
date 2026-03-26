# Phase 2: Recording + Fader + View Modes - Research

**Researched:** 2026-03-26
**Domain:** AVFoundation simultaneous capture + playback, CALayer fader blending, SwiftUI recording UI
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Full-screen video with overlay controls. Reference video fills entire screen, camera preview overlays on top (opacity via fader). Controls float as semi-transparent overlays at bottom.
- **D-02:** Navigate to recording via "Start Practice" button on ContentDetailView (from Phase 1). Full-screen recording view pushes in.
- **D-03:** Record button: center bottom, large circular red. Tap to start/stop. Pulsing red when recording.
- **D-04:** Auto-hide controls after 3 seconds during recording. Tap anywhere to show. Faders stay visible while being actively dragged.
- **D-05:** Video fader: horizontal slider above record button. Left = reference only, center = blended overlay, right = camera only. Uses CALayer opacity for GPU-composited blending.
- **D-06:** Audio fader: separate smaller horizontal slider. Controls AVPlayer.volume inversely proportional to position. Independent from video fader.
- **D-07:** Two separate faders — video and audio independently controlled.
- **D-08:** Default positions: Video starts at center (50/50 blend), Audio starts at reference-only (left).
- **D-09:** Haptic feedback at 0%, 50%, and 100% positions on both faders. UIImpactFeedbackGenerator light tap.
- **D-10:** Floating pill-shaped segmented control at top with 4 modes: Ref | Cam | Blend | Text.
- **D-11:** In text overlay mode, video fader controls text opacity over the video instead of camera/reference blend.
- **D-12:** Text overlay mode (VIEW-02): shows scrolling transcript on top of reference video with semi-transparent background.
- **D-13:** Text-only mode: auto-scroll with adjustable speed. Scrolling starts when recording starts, pauses when recording pauses.
- **D-14:** Teleprompter visual style: dark/black background, large white text, current line highlighted, text centered.
- **D-15:** Camera records simultaneously in teleprompter mode (user is recorded while reading the script).
- **D-16:** AVCaptureSession.automaticallyConfiguresApplicationAudioSession = false — MUST be set when creating AVCaptureSession (FOUND-02, deferred from Phase 1).
- **D-17:** AudioSessionManager already configured with .playAndRecord mode from Phase 1. No reconfiguration needed.

### Claude's Discretion

- CaptureEngine implementation details (AVCaptureSession setup, device configuration, output handling)
- Exact animation timing for control auto-hide/show
- Fader thumb size and visual design details
- View mode transition animations
- Teleprompter font size and line spacing specifics
- How to handle recording file naming and temporary storage

### Deferred Ideas (OUT OF SCOPE)

- Session saving (Phase 3) — recording output is temporary until Phase 3 adds persistence
- Review playback with fader (Phase 3) — same fader UI reused for review
- Playback speed control (v2 — PLAY-01)
- Loop in/out points (v2 — PLAY-02)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REC-01 | User can play reference content (video/audio/text) while simultaneously recording themselves via front camera | CaptureEngine + PlaybackEngine simultaneous operation; FOUND-02 (D-16) prevents audio conflict |
| REC-02 | Reference audio plays through headphones/AirPods while mic captures user's voice without bleed | AudioSessionManager already configures .playAndRecord; headphonesConnected check already exists in Phase 1 |
| REC-03 | User can see live camera preview overlaid on reference video during recording | CompositorView: AVPlayerLayer (bottom) + AVCaptureVideoPreviewLayer (top) stacked in UIViewRepresentable UIView |
| REC-04 | User can start/stop recording with clear visual indicators | AVCaptureMovieFileOutput + AVCaptureFileOutputRecordingDelegate; pulsing red button state from @Observable RecordingViewModel |
| REC-05 | App captures sync timestamp at recording start for accurate review playback alignment | CACurrentMediaTime() captured in startRecording() and stored with output file metadata — feeds Phase 3 session model |
| REC-06 | In text-only mode, text scrolls automatically during recording at configurable speed (teleprompter-style) | SwiftUI ScrollViewReader + Timer.publish pattern; scroll driven by RecordingViewModel.isRecording state |
| VIEW-01 | User can switch between view modes during recording: reference only, camera only, blended overlay, text overlay | ViewMode enum; segmented pill control drives CALayer opacity overrides and text overlay visibility |
| VIEW-02 | Text overlay mode shows scrolling transcript on top of reference video (semi-transparent background) | SwiftUI overlay with semi-transparent background on top of CompositorView; transcript from ReferenceContent.transcript |
| VIEW-03 | When transcript is available for video/audio, user can toggle text overlay on/off during playback and recording | ViewMode.textOverlay availability gated on ReferenceContent.transcript != nil |
| FADER-01 | User can slide a video fader to blend between reference video (left), overlay (center), and self-only (right) | Custom FaderView with DragGesture; maps 0.0–1.0 → AVCaptureVideoPreviewLayer.opacity |
| FADER-02 | User can slide an audio fader to blend between reference audio and their own recorded audio | FaderView bound to AVPlayer.volume (0.0–1.0); mic is passive (no volume control during capture) |
| FADER-03 | Fader UI runs at 60fps without dropped frames during both live recording and review playback | CALayer opacity is GPU-composited by system; zero CPU path confirmed from architecture research |
| FADER-04 | Video blend uses CALayer opacity for GPU-composited performance | AVCaptureVideoPreviewLayer.opacity on main thread; no AVMutableVideoComposition at live preview time |
</phase_requirements>

---

## Summary

Phase 2 is the core product differentiator of Mimzit: simultaneous recording and playback with a real-time DJ-fader blend. The architecture is fully defined in CLAUDE.md and the Phase 1 architecture research — this phase executes on those decisions rather than re-exploring alternatives.

The central technical structure is a `CompositorView` (UIViewRepresentable-wrapped UIView) that stacks an `AVPlayerLayer` (reference video, bottom) and `AVCaptureVideoPreviewLayer` (camera preview, top) as CALayer sublayers. The video fader maps directly to `previewLayer.opacity` on the main thread — GPU-composited at zero CPU cost. The audio fader maps to `AVPlayer.volume`. Both fader interactions are completely independent.

Phase 2 builds three new feature folders: `Recording/` (core session recording screen), `Engines/` (PlaybackEngine + CaptureEngine), and `Shared/` components (FaderView, CompositorView). It also wires the existing `ContentDetailView` "Start Practice" button and extends `Theme.swift` with recording-specific colors. Session persistence is explicitly out of scope — recording output files land in a temporary location that Phase 3 will persist.

**Primary recommendation:** Build CaptureEngine first on a dedicated serial queue, verify simultaneous AVPlayer + AVCaptureSession audio works on physical device before any UI work, then build CompositorView, then the full recording screen.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation (AVCaptureSession) | iOS 17+ | Camera capture, front-camera device, session lifecycle | Only first-party camera API; no alternative |
| AVFoundation (AVCaptureMovieFileOutput) | iOS 17+ | Write camera recording to .mov file | Simpler than AVAssetWriter; handles compression/container; sync-safe without stabilization |
| AVFoundation (AVCaptureVideoPreviewLayer) | iOS 17+ | Live camera preview as CALayer | Required for CALayer opacity blend; AVKit VideoPlayer cannot be used here |
| AVFoundation (AVPlayerLayer) | iOS 17+ | Reference video as CALayer in compositor | Required for CALayer opacity blend approach |
| AVFoundation (AVPlayer) | iOS 17+ | Reference video/audio playback with volume control | `AVPlayer.volume` is the audio fader target |
| QuartzCore (CALayer / CATransaction) | iOS 17+ | GPU-composited opacity for live fader | Main-thread opacity update; composited by system GPU at zero CPU cost |
| SwiftUI | iOS 17+ | All UI except video layers | Overlay controls, fader sliders, view mode pill, teleprompter text |
| UIKit (UIViewRepresentable) | iOS 17+ | Bridge for CompositorView and CapturePreviewView | CALayer hierarchy cannot be managed in pure SwiftUI |
| UIKit (UIImpactFeedbackGenerator) | iOS 17+ | Haptic snap at fader 0%/50%/100% | iOS 17 `.sensoryFeedback` modifier is the SwiftUI equivalent; both are valid |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Concurrency (async/await) | Swift 5.9+ | CaptureEngine async setup, permission checks | All async operations except AVCaptureSession lifecycle (that stays on sessionQueue) |
| NotificationCenter | iOS 17+ | AVCaptureSession interruption + AVAudioSession route changes | Subscribe from RecordingViewModel; already used by AudioSessionManager in Phase 1 |
| SwiftUI ScrollViewReader | iOS 14+ | Teleprompter programmatic scroll position | Combined with Timer.publish for auto-scroll |
| Timer.publish | iOS 13+ | Drive teleprompter scroll animation | Combine publisher on .main run loop, `.autoconnect()` |
| FileManager | iOS 17+ | Write temporary recording files to Documents/recordings/ | FileVault pattern already established; extend with recordings subdirectory |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CALayer.opacity for live fader | AVMutableVideoCompositionLayerInstruction | AVMutableVideoComposition cannot drive live preview; it is an export/render pipeline only. Never use for live fader. |
| AVCaptureMovieFileOutput | AVAssetWriter + AVCaptureVideoDataOutput | AVAssetWriter needed for per-frame access or pause/resume. Neither is required for Phase 2. AVAssetWriter + video stabilization causes 0.6s A/V desync (Pitfall 7). |
| UIImpactFeedbackGenerator .light | iOS 17 .sensoryFeedback(.impact(.light)) | Both valid. .sensoryFeedback is SwiftUI-native but requires iOS 17; since project targets iOS 17+, either works. |
| Two separate AVPlayers for audio mode | AVMutableComposition | Two AVPlayer approach is correct for in-app review (Phase 3). For audio-only reference: one AVPlayer for audio file, CaptureEngine for camera. |

**Installation:** No new dependencies. All APIs are in AVFoundation, QuartzCore, UIKit, and SwiftUI — all part of iOS SDK. No `npm install` or SPM packages needed.

---

## Architecture Patterns

### Recommended Project Structure

```
Mimzit/
├── App/
│   ├── MimzitApp.swift              # EXISTING — no changes needed
│   └── ContentView.swift            # MODIFY: hide tab bar during recording
├── Engines/                         # NEW FOLDER
│   ├── PlaybackEngine.swift         # NEW: AVPlayer + AVPlayerLayer
│   └── CaptureEngine.swift          # NEW: AVCaptureSession + AVCaptureMovieFileOutput
├── Features/
│   ├── Import/                      # EXISTING — modify ContentDetailView only
│   │   └── ContentDetailView.swift  # MODIFY: wire "Start Practice" button
│   └── Recording/                   # NEW FOLDER
│       ├── RecordingView.swift       # NEW: full-screen recording screen
│       ├── RecordingViewModel.swift  # NEW: @Observable @MainActor coordinator
│       ├── CompositorView.swift      # NEW: UIViewRepresentable CALayer stack
│       ├── FaderView.swift           # NEW: custom horizontal fader slider
│       ├── ViewModeControl.swift     # NEW: pill segmented control
│       └── TeleprompterView.swift    # NEW: auto-scroll text overlay
├── Models/
│   └── ReferenceContent.swift       # EXISTING — no changes needed
├── Services/
│   └── AudioSessionManager.swift    # EXISTING — no changes needed
├── Shared/
│   └── Theme.swift                  # MODIFY: add recording-specific colors
└── Utilities/
    └── FileVault.swift              # MODIFY: add recordings/ subdirectory support
```

### Pattern 1: CaptureEngine — Dedicated Serial Queue

**What:** All AVCaptureSession lifecycle operations (startRunning, stopRunning, beginConfiguration, commitConfiguration, startRecording, stopRecording) MUST run on a dedicated serial DispatchQueue. UI state updates are dispatched back to @MainActor.

**When to use:** Always. startRunning() is synchronous and blocks 200–500ms while camera hardware initializes.

**Example:**
```swift
// Source: AVFoundation architecture research + Apple AVCam sample
@Observable
@MainActor
final class CaptureEngine: NSObject {
    private let sessionQueue = DispatchQueue(label: "com.mimzit.capture", qos: .userInitiated)
    private let captureSession = AVCaptureSession()
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private var movieOutput = AVCaptureMovieFileOutput()

    // FOUND-02 (D-16): Must be set before adding any inputs
    func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.automaticallyConfiguresApplicationAudioSession = false
            self.captureSession.sessionPreset = .high  // 1080p30 for front camera
            // Add front camera input
            // Add microphone input
            // Add movie file output
            self.captureSession.commitConfiguration()
            Task { @MainActor in
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer?.videoGravity = .resizeAspectFill
            }
        }
    }

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

    func startRecording(to url: URL) {
        let syncTimestamp = CACurrentMediaTime()  // REC-05: capture before async
        sessionQueue.async { [weak self] in
            self?.movieOutput.startRecording(to: url, recordingDelegate: self!)
        }
        return syncTimestamp
    }
}
```

**Critical:** `automaticallyConfiguresApplicationAudioSession = false` must be set inside `beginConfiguration/commitConfiguration` block on the session queue, before adding any inputs. AudioSessionManager.configure() already ran at app launch (Phase 1), so this prevents AVCaptureSession from overriding it.

---

### Pattern 2: CompositorView — CALayer Stack for Live Fader

**What:** A `UIViewRepresentable`-wrapped `UIView` that stacks `AVPlayerLayer` (bottom) and `AVCaptureVideoPreviewLayer` (top) as CALayer sublayers. The video fader updates `previewLayer.opacity` on the main thread — GPU-composited at zero CPU cost.

**When to use:** All live video blending during recording. Never use AVMutableVideoComposition for this path.

**Example:**
```swift
// Source: CLAUDE.md architecture notes + AVFoundation architecture research
struct CompositorView: UIViewRepresentable {
    let playerLayer: AVPlayerLayer
    let previewLayer: AVCaptureVideoPreviewLayer
    @Binding var videoBlend: Float  // 0.0 = ref only, 1.0 = camera only

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Frame updates on main thread — CALayer layout
        CATransaction.begin()
        CATransaction.setDisableActions(true)  // No implicit animations on frame changes
        playerLayer.frame = uiView.bounds
        previewLayer.frame = uiView.bounds
        CATransaction.commit()

        // Opacity update — GPU-composited, zero CPU cost
        previewLayer.opacity = videoBlend
    }
}
```

**Critical:** `CATransaction.setDisableActions(true)` prevents implicit CALayer animations when the view resizes. Without it, layer frames animate unexpectedly on rotation or layout changes.

---

### Pattern 3: PlaybackEngine — AVPlayer + AVPlayerLayer

**What:** Wraps AVPlayer and exposes AVPlayerLayer for insertion into CompositorView. Provides volume control for audio fader.

**When to use:** Any time reference content needs to play. For audio-only content, AVPlayer plays without a visible layer but still feeds audio fader.

**Example:**
```swift
// Source: AVFoundation architecture research
@Observable
@MainActor
final class PlaybackEngine {
    private(set) var player = AVPlayer()
    private(set) var playerLayer = AVPlayerLayer()
    var volume: Float = 1.0 {
        didSet { player.volume = volume }
    }

    init() {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        // Cap decode resolution to screen — Pitfall 6 prevention
        item.preferredMaximumResolution = UIScreen.main.nativeBounds.size
        player.replaceCurrentItem(with: item)
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func seek(to time: CMTime) { player.seek(to: time) }
}
```

---

### Pattern 4: RecordingViewModel — Session Coordinator

**What:** @Observable @MainActor class that owns PlaybackEngine, CaptureEngine, and all recording state. SwiftUI RecordingView reads from it exclusively.

**Example:**
```swift
// Source: Architecture research pattern
@Observable
@MainActor
final class RecordingViewModel: NSObject, AVCaptureFileOutputRecordingDelegate {
    let playbackEngine = PlaybackEngine()
    let captureEngine = CaptureEngine()
    let content: ReferenceContent

    var isRecording = false
    var videoBlend: Float = 0.5   // D-08: default center
    var audioBlend: Float = 0.0   // D-08: default reference-only
    var activeViewMode: ViewMode = .blend
    var controlsVisible = true
    var syncTimestamp: Double = 0

    private var controlsHideTask: Task<Void, Never>?

    func startRecording() {
        let outputURL = FileVault.recordingURL(filename: "\(UUID().uuidString).mov")
        syncTimestamp = CACurrentMediaTime()  // REC-05
        captureEngine.startRecording(to: outputURL, delegate: self)
        playbackEngine.play()
        isRecording = true
        scheduleControlsHide()  // D-04
    }

    func stopRecording() {
        captureEngine.stopRecording()
        playbackEngine.pause()
        isRecording = false
    }

    // AVCaptureFileOutputRecordingDelegate
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo url: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        // Phase 3 will persist this URL; for Phase 2 just log it
        Task { @MainActor in
            // TODO(Phase 3): SessionStore.save(...)
        }
    }
}
```

---

### Pattern 5: FaderView — Custom Drag Gesture Slider

**What:** A custom horizontal slider built with DragGesture (not SwiftUI Slider) to control thumb appearance, snap haptics, and visual design precisely.

**When to use:** Both video and audio faders. SwiftUI's built-in Slider works but cannot be visually customized to the DJ-fader design or add snap-point haptics easily.

**Example:**
```swift
// Source: SwiftUI DragGesture pattern + UIImpactFeedbackGenerator
struct FaderView: View {
    @Binding var value: Float  // 0.0 to 1.0
    let snapPoints: [Float] = [0.0, 0.5, 1.0]  // D-09 haptic positions
    private let snapRadius: Float = 0.05

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .offset(x: CGFloat(value) * (geometry.size.width - 28))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Float(drag.location.x / geometry.size.width)
                            .clamped(to: 0...1)
                        // Haptic snap detection (D-09)
                        for snap in snapPoints {
                            if abs(newValue - snap) < snapRadius && abs(value - snap) >= snapRadius {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                        value = newValue
                    }
            )
        }
        .frame(height: 44)  // Touch target
    }
}
```

**Note:** iOS 17 introduces `.sensoryFeedback(.impact(.light), trigger:)` as a SwiftUI-native alternative to UIImpactFeedbackGenerator. Since the project targets iOS 17+, either works. UIImpactFeedbackGenerator gives more control over timing relative to the threshold crossing.

---

### Pattern 6: Teleprompter Auto-Scroll

**What:** ScrollViewReader + Timer.publish drives auto-scroll through transcript text. Scroll speed controlled by a speed multiplier. Scroll starts/pauses in sync with isRecording state.

**When to use:** REC-06 — text-only content type, or VIEW-01 text overlay mode when transcript is available.

**Example:**
```swift
// Source: SwiftUI ScrollViewReader docs + Timer.publish pattern
struct TeleprompterView: View {
    let text: String
    @Binding var isScrolling: Bool
    @Binding var scrollSpeed: Double  // lines per second multiplier

    @State private var scrollOffset: CGFloat = 0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text)
                    .font(.system(size: 32, weight: .medium))  // D-14: large text
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .id("teleprompterText")
            }
            .background(Color.black)
            .onReceive(timer) { _ in
                guard isScrolling else { return }
                scrollOffset += scrollSpeed * 0.05
                proxy.scrollTo("teleprompterText", anchor: UnitPoint(x: 0.5, y: scrollOffset))
            }
        }
    }
}
```

**Important:** For smooth teleprompter scrolling, `ScrollViewReader.scrollTo(_:anchor:)` with a continuously updated `UnitPoint.y` can produce jerky scrolling at high granularity. A more robust approach uses `withAnimation(.linear(duration: 0.05))` around the scroll call, or uses `UIScrollView` directly via UIViewRepresentable for pixel-perfect smooth scrolling. The simple timer approach should be prototyped first; switch to UIScrollView wrapper only if scroll jitter is observed on device.

---

### Pattern 7: Auto-Hide Controls

**What:** Controls overlay auto-hides after 3 seconds of inactivity (D-04). Tapping the screen shows controls and resets the timer. Faders remain visible while dragging.

**Example:**
```swift
// Source: Swift Concurrency Task-based timer pattern
private func scheduleControlsHide() {
    controlsHideTask?.cancel()
    controlsHideTask = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            controlsVisible = false
        }
    }
}

private func showControls() {
    withAnimation(.easeIn(duration: 0.2)) {
        controlsVisible = true
    }
    if isRecording {
        scheduleControlsHide()
    }
}
```

**Note:** Cancelling and recreating the Task each time is cleaner than a Timer/debounce pattern here, and Swift Concurrency makes it trivial. The `guard !Task.isCancelled` check is mandatory to prevent a cancelled task from hiding controls.

---

### Pattern 8: ViewMode Enum

**What:** A Swift enum drives the 4 view modes (D-10). The active mode determines CompositorView layer visibility, text overlay presence, and fader semantics (D-11).

**Example:**
```swift
enum ViewMode: String, CaseIterable {
    case reference = "Ref"
    case camera = "Cam"
    case blend = "Blend"
    case textOverlay = "Text"

    var showsReferenceLayer: Bool {
        switch self {
        case .reference, .blend, .textOverlay: return true
        case .camera: return false
        }
    }

    var showsCameraLayer: Bool {
        switch self {
        case .camera, .blend: return true
        case .reference, .textOverlay: return false
        }
    }

    var showsTextOverlay: Bool {
        return self == .textOverlay
    }
}
```

**D-11 implementation:** In `.textOverlay` mode, the video fader slider value maps to `textOverlayOpacity` instead of `previewLayer.opacity`. RecordingViewModel checks `activeViewMode` before routing the fader value.

---

### Anti-Patterns to Avoid

- **Never call `captureSession.startRunning()` on the main thread:** Blocks UI for 200–500ms. Always dispatch to `sessionQueue`.
- **Never set `automaticallyConfiguresApplicationAudioSession = true` (the default):** This silently overrides .playAndRecord and kills reference audio the moment capture starts. Set to `false` immediately after creating the session.
- **Never use AVMutableVideoComposition for live preview:** It is an offline render pipeline. Use CALayer.opacity.
- **Never use AVKit VideoPlayer for the recording screen:** It wraps AVPlayerLayer and hides layer controls. Use AVPlayerLayer directly in UIViewRepresentable.
- **Never store absolute file paths in FileVault for recordings:** Store relative filenames only (same pattern as Phase 1 content files).
- **Never call `movieOutput.startRecording` before `captureSession.isRunning`:** Will silently fail with no recording. Check `captureSession.isRunning` before calling startRecording.
- **Never trust `movieOutput.recordedDuration` for sync offset:** Use `CACurrentMediaTime()` captured at recording start (REC-05, Pitfall 4).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Camera preview in SwiftUI | A custom render loop or Metal view | AVCaptureVideoPreviewLayer in UIViewRepresentable | Apple's layer handles hardware decode, mirroring, orientation, and display link for free |
| Audio session conflict resolution | Custom audio routing logic | .playAndRecord + automaticallyConfiguresApplicationAudioSession = false | One-line fix; custom routing adds fragile edge cases |
| Haptic feedback debouncing | Tracking previous trigger states in closures | UIImpactFeedbackGenerator with threshold check on value change | Simple threshold comparison handles all snap-point cases |
| Teleprompter scroll physics | Custom UIScrollView delegate + deceleration model | Timer.publish at 0.05s intervals with linear position increment | Sufficient for v1; custom physics only if user testing shows inadequacy |
| Recording file naming | Complex naming schemes | UUID().uuidString + ".mov" | Globally unique, no collisions, human-unreadable is fine (display via session title in Phase 3) |
| Session interruption recovery | Custom state machine from scratch | AVCaptureSessionWasInterruptedNotification + AVCaptureSessionInterruptionEndedNotification | Apple's notifications cover all interruption types including Siri, phone calls, and background |

**Key insight:** AVFoundation already solves the hard problems (hardware access, codec, routing, GPU compositing). Phase 2 is plumbing, not algorithm work.

---

## Common Pitfalls

### Pitfall 1: FOUND-02 Not Set — AVCaptureSession Kills Reference Audio

**What goes wrong:** `AVCaptureSession.automaticallyConfiguresApplicationAudioSession` defaults to `true`. When AVCaptureSession adds a microphone input, it silently reconfigures AVAudioSession, overriding the .playAndRecord + .allowBluetoothA2DP setup from Phase 1. Reference video audio goes silent the moment recording starts.

**Why it happens:** Developers initialize AVCaptureSession, add inputs, then wonder why AVPlayer goes silent. The override is silent with no log output.

**How to avoid:** Set `captureSession.automaticallyConfiguresApplicationAudioSession = false` inside `beginConfiguration/commitConfiguration` BEFORE adding any inputs. This is FOUND-02, explicitly deferred from Phase 1 to this phase (D-16).

**Warning signs:** Reference video audio cuts out exactly when recording starts; works fine in playback-only mode.

---

### Pitfall 2: startRecording Called Before Session Is Running

**What goes wrong:** `AVCaptureMovieFileOutput.startRecording(to:recordingDelegate:)` silently does nothing if the capture session is not yet running. The user taps "Record" and nothing happens.

**Why it happens:** `captureSession.startRunning()` is async to the session queue. If you call startRecording immediately in the same button tap, the session may not be running yet.

**How to avoid:** Check `captureSession.isRunning` before calling startRecording. If not running yet, start session first and call startRecording in the session started callback, or use a `Task` with an `await` loop checking `isRunning`.

**Warning signs:** `fileOutput(_:didStartRecordingTo:)` delegate callback never fires; recording indicator appears but no file is written.

---

### Pitfall 3: CATransaction Implicit Animations on Layer Frame Changes

**What goes wrong:** When CompositorView is resized (e.g., keyboard appears, screen rotates), CALayer frames animate implicitly with a ~0.25s ease-in-out animation. Video layer "slides" to its new frame instead of jumping, causing a jarring visual glitch.

**Why it happens:** CALayer has implicit animations enabled by default for frame, bounds, and position changes.

**How to avoid:** Wrap all frame updates in `CATransaction.begin()` / `CATransaction.setDisableActions(true)` / `CATransaction.commit()`. Do this in `updateUIView`.

**Warning signs:** Layer frame changes animate visibly; video "slides" when view layout changes.

---

### Pitfall 4: AVCaptureVideoPreviewLayer Mirroring for Front Camera

**What goes wrong:** Front camera preview renders mirrored by default (like a selfie mirror), which is usually correct UX. However if you disable mirroring via `connection.isVideoMirrored = false`, the preview shows the "correct" unmirrored orientation that can feel unnatural for the user watching themselves.

**Why it happens:** AVCaptureVideoPreviewLayer mirrors front camera automatically (since iOS 6). Explicit `.isVideoMirrored` overrides this.

**How to avoid:** Leave the default mirroring for the live preview (correct UX — users expect a mirror). The recorded file will be the unmirrored version, which is also correct for review. Do not set `isVideoMirrored` explicitly.

**Warning signs:** Live preview looks "wrong way" when user waves their right hand; preview feels unnatural.

---

### Pitfall 5: AVPlayer Looping Not Set for Reference Content

**What goes wrong:** Reference video ends before the user finishes recording. AVPlayer stops, the reference layer goes black, but the user is still recording. The recording becomes useless for comparison.

**Why it happens:** AVPlayer does not loop by default. Short reference clips (30 seconds) end quickly during a 2-minute practice session.

**How to avoid:** Add `NotificationCenter` observer for `.AVPlayerItemDidPlayToEndTime`. On notification, seek player to `.zero` and `play()` again. This creates a basic loop. Add `NotificationCenter.addObserver(forName: .AVPlayerItemDidPlayToEndTime, ...)` in PlaybackEngine.

**Warning signs:** Reference video goes black mid-recording; users have short reference clips; review shows misaligned timing for sessions longer than reference duration.

---

### Pitfall 6: Teleprompter ScrollViewReader Scroll Jitter

**What goes wrong:** `ScrollViewReader.scrollTo(_:anchor:)` called from a timer with small deltas produces visible jitter or stuttering instead of smooth linear motion.

**Why it happens:** SwiftUI's ScrollViewReader scroll calls coalesce with the render cycle; rapid calls in tight timer intervals can produce uneven visual updates.

**How to avoid:** Use `withAnimation(.linear(duration: timerInterval))` wrapping the `scrollTo` call. If jitter persists on device, switch to a UIScrollView UIViewRepresentable with `setContentOffset(_:animated: false)` and an explicit `CADisplayLink` for frame-rate-accurate scrolling.

**Warning signs:** Text appears to "jump" in small increments rather than smooth glide; noticeable on longer text blocks.

---

### Pitfall 7: Tab Bar Visible During Full-Screen Recording

**What goes wrong:** SwiftUI TabView's tab bar persists behind the full-screen recording view, breaking the immersive full-screen experience (D-01).

**Why it happens:** The recording view is presented as a fullScreenCover or pushed NavigationStack destination, but TabView's bar still renders underneath unless explicitly hidden.

**How to avoid:** Use `.fullScreenCover(isPresented:)` presentation for RecordingView, OR use `.toolbar(.hidden, for: .tabBar)` on the recording view (iOS 16+). The `.fullScreenCover` approach is cleaner since it completely removes the tab context.

**Warning signs:** Tab bar visible at the bottom of the recording screen; reference video area is reduced by tab bar height.

---

## Code Examples

### CaptureEngine Front Camera + Microphone Setup

```swift
// Source: Apple AVFoundation documentation + architecture research
private func configureCaptureInputs() {
    // Front camera (D-01: user self-recording)
    guard let camera = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: .front
    ) else { return }

    // Microphone
    guard let microphone = AVCaptureDevice.default(for: .audio) else { return }

    do {
        let cameraInput = try AVCaptureDeviceInput(device: camera)
        let micInput = try AVCaptureDeviceInput(device: microphone)

        captureSession.beginConfiguration()
        captureSession.automaticallyConfiguresApplicationAudioSession = false  // FOUND-02
        captureSession.sessionPreset = .high  // 1080p30 front camera

        if captureSession.canAddInput(cameraInput) { captureSession.addInput(cameraInput) }
        if captureSession.canAddInput(micInput) { captureSession.addInput(micInput) }
        if captureSession.canAddOutput(movieOutput) { captureSession.addOutput(movieOutput) }

        captureSession.commitConfiguration()
    } catch {
        print("CaptureEngine configuration error: \(error)")
    }
}
```

### REC-05 Sync Timestamp Capture

```swift
// Source: Pitfalls research — CACurrentMediaTime for recording sync
// Called in RecordingViewModel.startRecording()
// syncTimestamp stored for Phase 3 to use as review offset
let syncTimestamp = CACurrentMediaTime()
let referenceStartTime = CACurrentMediaTime()
// Both timestamps captured atomically before async operations begin
// Delta = syncTimestamp - referenceStartTime (ideally ~0 if both start simultaneously)
```

### AVCaptureFileOutputRecordingDelegate

```swift
// Source: Apple AVCaptureFileOutputRecordingDelegate documentation
extension RecordingViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                // Handle recording failure
                print("Recording failed: \(error)")
            } else {
                // Phase 3: persist session with syncTimestamp + outputFileURL
                // Phase 2: temporary file exists at outputFileURL
                self.lastRecordingURL = outputFileURL
            }
            self.isRecording = false
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            self.isRecording = true
        }
    }
}
```

### AVCaptureSession Interruption Handling

```swift
// Source: PITFALLS.md Pitfall 3 + Apple AVCaptureSession documentation
// Subscribe in CaptureEngine or RecordingViewModel
NotificationCenter.default.addObserver(
    forName: .AVCaptureSessionWasInterrupted,
    object: captureSession,
    queue: .main
) { notification in
    // Stop recording cleanly on phone call, Siri, background
    if self.isRecording {
        self.stopRecording()
    }
}

NotificationCenter.default.addObserver(
    forName: .AVCaptureSessionInterruptionEnded,
    object: captureSession,
    queue: .main
) { _ in
    // Do NOT auto-resume — let user re-initiate
}
```

### AVPlayer Loop for Reference Content

```swift
// Source: AVPlayerItem notification pattern
private func setupPlayerLoop() {
    NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: player.currentItem,
        queue: .main
    ) { [weak self] _ in
        self?.player.seek(to: .zero)
        self?.player.play()
    }
}
```

### FileVault Extension for Recordings

```swift
// Source: Phase 1 FileVault pattern — extend with recordings/ subdirectory
extension FileVault {
    static var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings", isDirectory: true)
    }

    static func recordingURL(filename: String) -> URL {
        try? FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
        return recordingsDirectory.appendingPathComponent(filename)
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.allowBluetooth` (deprecated) | `.allowBluetoothHFP` (explicit HFP) | iOS 8 (silently aliased since then) | Phase 1 already uses `.allowBluetoothA2DP` only; Phase 2 should NOT add `.allowBluetoothHFP` — AudioSessionManager is correctly configured |
| UIImagePickerController for media | PhotosUI.PhotosPicker | iOS 14 (deprecated UIImagePickerController) | Phase 1 already uses PHPickerViewController correctly |
| CoreData for persistence | SwiftData (iOS 17+) | iOS 17 | Phase 1 already uses SwiftData with MimzitMigrationPlan |
| iOS 17 `.sensoryFeedback` not available | `.sensoryFeedback(.impact(.light), trigger:)` available | iOS 17 | Project targets iOS 17+; either haptic approach valid |
| `AVCaptureSession` single output restriction | Multi-output allowed (video preview + movie file simultaneously) | iOS 16 | Phase 2 depends on this — confirmed iOS 16 lifted restriction; project now targets iOS 17 so no concern |

**Deprecated/outdated to avoid:**
- `AVCaptureMovieFileOutput.recordedDuration`: Inaccurate. Use `CACurrentMediaTime()` delta instead (REC-05).
- `UIImagePickerController`: Already excluded from project by CLAUDE.md.
- `ReplayKit`: Excluded by CLAUDE.md — cannot capture AVPlayer video and not designed for front-camera capture.

---

## Open Questions

1. **AVCaptureVideoPreviewLayer orientation on iPhone**
   - What we know: `AVCaptureVideoPreviewLayer` with `.videoGravity = .resizeAspectFill` fills the frame. On iPhone, video recording in portrait orientation may produce landscape video metadata that needs a connection transform.
   - What's unclear: Whether `AVCaptureConnection.videoRotationAngle` (iOS 17+) or the older `videoOrientation` property is needed for correct portrait recording orientation.
   - Recommendation: In CaptureEngine, set the connection's `videoRotationAngle` to match `UIDevice.current.orientation` on configuration. Apple's WWDC 2023 "Create a more responsive camera experience" recommends `videoRotationAngle` over the deprecated `videoOrientation` property for iOS 17+.

2. **Audio capture with text-only content (no AVPlayer)**
   - What we know: REC-01 says "play reference content (video/audio/text) while recording." For text-only content, there is no AVPlayer audio — the user reads silently from the teleprompter.
   - What's unclear: Should the audio fader still appear in teleprompter-only mode? What does AudioBlend = 0 mean when there is no reference audio?
   - Recommendation: Hide or disable the audio fader when `content.contentType == .text` since there is no reference audio to blend. The video fader also becomes the text opacity fader (D-11) in this mode.

3. **Recording file cleanup between sessions (before Phase 3 persistence)**
   - What we know: Phase 3 adds session persistence. In Phase 2, recording files land in `Documents/recordings/` with UUID filenames.
   - What's unclear: If the user records multiple sessions in Phase 2 without Phase 3's cleanup, recording files accumulate indefinitely.
   - Recommendation: In Phase 2, write the recording URL to a `@AppStorage` or temporary in-memory variable. Add a cleanup routine in `MimzitApp` that deletes any `.mov` files in `Documents/recordings/` that are older than 24 hours OR that exceed a count threshold. This is temporary scaffolding until Phase 3.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ | Build/compile | Yes | Xcode 26.2 (Build 17C52) | — |
| iOS Simulator (iPhone) | UI development | Yes | iPhone 17 Pro (Booted) | — |
| Physical iPhone device | AVCaptureSession testing | Not verified via script | — | Cannot validate camera without physical device |
| AVFoundation | All capture/playback | Yes (part of iOS SDK) | iOS 17+ | — |
| Swift 5.10+ | Swift Concurrency (async/await) | Yes (Xcode 26.2) | Swift 5.10 | — |

**Physical device requirement:** AVCaptureSession requires a physical iPhone for all recording testing. The iOS Simulator provides no real camera feed. All CaptureEngine validation tasks must be tested on device.

**Missing dependencies with fallback:**
- Physical device: Simulator can be used for UI layout and PlaybackEngine development. CaptureEngine tasks require physical device testing.

---

## Project Constraints (from CLAUDE.md)

These directives are mandatory and override any conflicting research recommendations:

| Directive | Constraint | Impact on Phase 2 |
|-----------|------------|-------------------|
| AVKit VideoPlayer | DO NOT use for recording screen | RecordingView uses CompositorView (UIViewRepresentable + AVPlayerLayer), never AVKit VideoPlayer |
| UIImagePickerController | Never use | Phase 2 has no import; already excluded |
| ReplayKit | Never use | Not relevant to Phase 2 |
| RxSwift / Combine | Avoid | Use Swift Concurrency (async/await) + NotificationCenter; no Combine publishers |
| AVAssetWriter (direct) | Avoid unless pixel buffer access needed | Use AVCaptureMovieFileOutput; no per-frame processing needed in Phase 2 |
| Background recording | Do not support | Handle UIApplicationWillResignActiveNotification to pause/stop recording |
| SwiftData for binary video | Never store video bytes in SwiftData | Recording files in FileVault.recordingsDirectory; only filename stored in Phase 3 model |
| CALayer opacity for live fader | Use this, not AVMutableVideoComposition | CompositorView.previewLayer.opacity = videoBlend (FADER-04) |
| sessionPreset = .hd4K3840x2160 | Never use | CaptureEngine uses .high (1080p30) |
| Third-party video players | Never use | All AVPlayer; no VLCKit or similar |
| automaticallyConfiguresApplicationAudioSession | Set to false | FOUND-02, D-16 — first action in CaptureEngine.configure() |
| GSD workflow enforcement | Use GSD commands for all file changes | /gsd:execute-phase for all implementation work |

---

## Sources

### Primary (HIGH confidence)
- CLAUDE.md — Stack decisions, AVFoundation patterns, explicit anti-patterns list; all CLAUDE.md directives are enforced
- `.planning/research/ARCHITECTURE.md` — AVFoundation architecture patterns, CALayer stack, CaptureEngine serial queue, CompositorView pattern
- `.planning/research/PITFALLS.md` — 7 critical pitfalls with prevention strategies; all verified against Apple Developer Forums and official docs
- Apple AVCaptureMovieFileOutput docs — `startRecording(to:recordingDelegate:)` delegate pattern
- Apple AVCaptureFileOutputRecordingDelegate docs — `fileOutput(_:didFinishRecordingTo:from:error:)` delegate signature
- Apple CALayer docs — `.opacity` property, CATransaction, implicit animations

### Secondary (MEDIUM confidence)
- [AVCaptureVideoPreviewLayer UIViewRepresentable patterns — createwithswift.com](https://www.createwithswift.com/integrating-device-camera-in-swiftui-apps/) — confirmed UIViewRepresentable wrapping pattern
- [Auto-Scrolling ScrollViewReader — Medium](https://medium.com/@mikeusru/auto-scrolling-with-scrollviewreader-in-swiftui-10f16dce7dbb) — Timer.publish auto-scroll pattern confirmed
- [UIImpactFeedbackGenerator documentation — Apple](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator) — haptic generation API confirmed
- Phase 1 codebase (AudioSessionManager, FileVault, ReferenceContent, ContentDetailView) — directly read, HIGH confidence on integration points

### Tertiary (LOW confidence)
- Teleprompter scroll jitter mitigation (UIScrollView vs ScrollViewReader) — based on general knowledge; needs device validation during implementation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs are first-party iOS SDK; confirmed in CLAUDE.md and architecture research
- Architecture: HIGH — patterns fully defined in architecture research and CLAUDE.md; Phase 1 codebase read directly
- Pitfalls: HIGH — 7 pitfalls verified in PITFALLS.md with Apple Developer Forums citations; directly applicable
- Teleprompter scroll smoothness: MEDIUM — Timer.publish pattern is well-established; pixel-level smoothness needs device validation

**Research date:** 2026-03-26
**Valid until:** 2026-06-26 (AVFoundation APIs are stable; 90-day validity reasonable)
