# Project Research Summary

**Project:** Spikzit
**Domain:** Native iOS speech shadowing app — simultaneous video playback + front camera recording with DJ-fader visual blend
**Researched:** 2026-03-25
**Confidence:** HIGH

## Executive Summary

Spikzit is a native iOS app in a category with no direct competitor. Every existing speech shadowing app (ShadowSpeak, TubeShad, Speak Pro, SpeakVibe) records audio-only or video-only. None combine simultaneous reference video playback with live front-camera capture and a real-time visual blend control. The entire product value lives in one interaction: the DJ-fader that lets the user slide between seeing themselves and seeing the reference speaker, both video and audio, in real time. Everything else is scaffolding to make that interaction possible.

The recommended technical approach is a pure Apple stack — Swift, SwiftUI, AVFoundation, SwiftData — with no third-party dependencies. The critical architectural insight is that two separate CALayer objects (AVPlayerLayer for reference video, AVCaptureVideoPreviewLayer for the camera) stacked in a UIView, with opacity driven by the fader slider, deliver real-time 60fps blending at near-zero CPU cost via the system GPU compositor. This is the correct approach for live preview. AVMutableVideoComposition is for export pipelines, not live blending, and reaching for it prematurely is the #1 architectural mistake in this domain.

The primary risk area is AVAudioSession management. The shared AVAudioSession singleton must be configured exactly once (playAndRecord + allowBluetooth + allowBluetoothA2DP), AVCaptureSession's automatic audio reconfiguration must be disabled, and headphone route detection must gate recording start. Getting audio wrong makes every recorded session unusable — reference audio bleeds into the microphone track when no headphones are connected, and AVCaptureSession silently kills reference audio if it reconfigures the session. These are not edge cases to handle later; they are Phase 1 requirements.

## Key Findings

### Recommended Stack

The entire app is buildable on Apple system frameworks with zero external dependencies. Swift 5.10+ with SwiftUI handles all non-video UI. AVFoundation handles all media work — camera, playback, and recording. SwiftData (iOS 17 minimum, recommended over iOS 16 given 88%+ iOS 18 adoption) handles session metadata persistence with zero boilerplate via @Query. Video files are stored as .mov files in the app's Documents directory via FileManager; only relative filenames go into SwiftData.

**Core technologies:**
- Swift 5.10 / Xcode 16: primary language — async/await and ARC make AVFoundation integration clean
- SwiftUI (iOS 17+): all non-video UI — session history, settings, import, fader controls
- AVFoundation / AVPlayer + AVCaptureSession: all media — playback, preview, and recording
- AVAudioSession (.playAndRecord): shared audio session managing simultaneous mic input and speaker/headphone output
- SwiftData: session metadata (title, timestamps, relative file paths) — @Observable integrates directly with SwiftUI
- PhotosUI SwiftUI PhotosPicker (iOS 16+): reference video import from Camera Roll, no wrapper needed
- FileManager (Documents directory): .mov file storage; binary video never enters the database
- AVCaptureMovieFileOutput: user recording to file — simpler than AVAssetWriter, handles audio-video sync correctly when video stabilization is present

**What not to use:**
- AVKit VideoPlayer on the recording screen — hides AVPlayerLayer, blocks fader control
- AVMutableVideoComposition for live preview — export pipeline only, not live camera
- UIImagePickerController — deprecated, use PhotosPicker
- Third-party video libraries (VLCKit, etc.) — conflict with AVAudioSession, no benefit over native

### Expected Features

**Must have (v1 table stakes):**
- Import reference video from Camera Roll (PHPickerViewController, mp4/mov)
- Play reference video while simultaneously capturing user via front camera
- Audio routing: reference to headphones/AirPods, mic captures user voice only
- DJ-fader video blend: reference to overlay to self-only in real time (the differentiator)
- DJ-fader audio blend: independent audio cross-fade between reference and user audio
- Save session: reference path + user recording + timestamp as a linked pair
- Session history list: navigate past practice sessions
- Review past sessions with the same fader UI: closes the training loop

**Should have (v1.x, add after validation):**
- Segment looping: set in/out points for drilling hard sections (TubeShad's most praised feature)
- Playback speed control: 0.5x / 0.75x / 1x during reference playback
- Session rename and notes: label sessions when history grows
- Export session to Camera Roll: user-initiated via iOS share sheet

**Defer (v2+):**
- AI phoneme / pronunciation analysis — requires ML infrastructure; risk of poor analysis generating complaints
- iCloud Drive backup — complexity spike, conflicts with "fully offline" positioning
- Waveform visualization — validate demand first

**Competitive position:** No iOS app combines user-supplied reference video + simultaneous front-camera recording + visual blend comparison. SpeakVibe records video of the user but has no reference video overlay. All audio-only shadowing apps miss the body language and visual delivery dimension entirely. Spikzit's offline / no-account positioning is an additional differentiator in a category where every competitor requires an account.

**Anti-features to avoid:** YouTube/internet video import (ToS violation, App Store risk), AI phoneme scoring in v1 (scope is a separate product), built-in content library (licensing complexity), real-time AI feedback during recording (thermal load on AVCaptureSession, unproven on-device latency).

### Architecture Approach

The architecture is a four-layer system: SwiftUI views, @Observable ViewModels, AVFoundation engine classes (AudioSessionManager, PlaybackEngine, CaptureEngine, CompositorView), and a Persistence layer (SwiftData SessionStore + FileManager FileVault). The critical isolation rule is that SwiftUI views never touch AVFoundation directly; engines do not hold ViewModel references; and AVFoundation objects are grouped in an Engines/ directory separate from Features/. AVAudioSession is a singleton configured once at app launch via AudioSessionManager before either playback or capture engine starts.

**Major components:**
1. AudioSessionManager — configure AVAudioSession once at app launch; handle route changes (AirPods connect/disconnect); handle interruptions (phone calls, Siri); all other components depend on this being correct
2. PlaybackEngine — wraps AVPlayer + AVPlayerLayer; exposes layer for CompositorView; exposes volume property for audio fader
3. CaptureEngine — wraps AVCaptureSession + AVCaptureMovieFileOutput; all session lifecycle calls on a dedicated serial DispatchQueue (never the main thread); exposes AVCaptureVideoPreviewLayer for CompositorView
4. CompositorView — UIViewRepresentable wrapping a UIView; stacks AVPlayerLayer (bottom) and AVCaptureVideoPreviewLayer (top); exposes setVideoBlend(_ value: Float) which maps directly to previewLayer.opacity — GPU composited, no CPU cost
5. SessionStore — SwiftData CRUD for PracticeSession @Model; no AVFoundation dependencies
6. FileVault — only component that calls FileManager; resolves relative filenames to absolute URLs at runtime (never store absolute paths — the container UUID changes on reinstall)
7. ReviewViewModel — instantiates two PlaybackEngine instances from stored file URLs; drives the same CompositorView and FaderControlView used during recording; no CaptureEngine involved in review

**Key patterns:**
- CALayer opacity for live fader (not AVMutableVideoComposition — that is for export only)
- CaptureEngine on dedicated serial DispatchQueue (startRunning blocks the calling thread for 200-500ms)
- AVCaptureMovieFileOutput over AVAssetWriter for MVP (simpler, handles stabilization sync automatically)
- Store only relative filenames in SwiftData; reconstruct absolute URLs at runtime via FileVault
- Review playback: two AVPlayer instances with periodic time observer sync (±0.1s tolerance) — simpler than AVMutableComposition, no offline render overhead

### Critical Pitfalls

1. **AVCaptureSession auto-reconfigures AVAudioSession and kills reference audio** — set `captureSession.automaticallyConfiguresApplicationAudioSession = false` before adding any inputs; configure AVAudioSession manually with `.playAndRecord` + `.mixWithOthers` + `.allowBluetoothA2DP` before either engine starts. This is a silent failure with no log output — the reference video goes silent the moment recording begins and there is no error to catch.

2. **Reference audio bleeds into the user's recorded track without headphones** — the front mic picks up speaker output when no headphones are connected. Detect output route via `AVAudioSession.sharedInstance().currentRoute.outputs` before allowing recording to start; show a blocking prompt if no headphones are connected. Do not add this as a "nice to have" — it makes every speaker-mode recording unusable.

3. **AVCaptureMovieFileOutput recordedDuration is inaccurate by hundreds of milliseconds** — never use `recordedDuration` for sync offset in review playback. Record `CACurrentMediaTime()` at the exact moment both AVPlayer and AVCaptureSession start; store this offset in the PracticeSession model; use it to align the two players in ReviewViewModel. This must be designed into the data model in Phase 1; it cannot be retrofitted without re-architecting review playback.

4. **Background/interruption silently destroys recording** — subscribe to `AVCaptureSessionWasInterruptedNotification`; on interruption, stop recording, save the partial file, and update UI state. Test with a real phone call mid-recording before shipping. The UI showing "recording" while nothing is being captured is a user-trust failure.

5. **Memory pressure from two simultaneous video pipelines on older devices** — cap AVPlayer reference video to display resolution via `preferredMaximumResolution`; set `AVCaptureSession.sessionPreset` to `.high` (1080p30), never 4K. Profile with Instruments on the oldest supported device (iPhone with iOS 17). Memory termination mid-session has no crash log visible to the user and will generate one-star reviews.

## Implications for Roadmap

The architecture research provides a validated build order. Dependencies flow bottom-up: audio session correctness gates all media work; import gates recording; recording gates save; save gates history; history gates review. The roadmap must follow this dependency chain.

### Phase 1: Foundation + Core Recording Engine

**Rationale:** Every other phase depends on AVAudioSession being correct and the simultaneous playback + capture pipeline working. This is not a "nice to have first" — it is an absolute prerequisite. Getting audio wrong at this stage means every session recorded in subsequent phases is unusable. The seven critical pitfalls all resolve in this phase.

**Delivers:** Working simultaneous reference video playback + front camera recording with correct audio routing; headphone route detection; interruption handling; file written to Documents directory; sync timestamp captured.

**Features addressed:** "Play reference video while simultaneously capturing user via front camera," "Audio routing: reference to headphones, mic captures user voice only"

**Pitfalls to prevent:** Auto audio session override (disable automaticallyConfiguresApplicationAudioSession), acoustic bleed (route detection gate), interruption data loss (notification observers), AVAssetWriter stabilization sync (use AVCaptureMovieFileOutput instead), memory pressure (set resolution caps from day one)

**Components built:** AudioSessionManager, PlaybackEngine (AVPlayer + AVPlayerLayer), CaptureEngine (AVCaptureSession + AVCaptureMovieFileOutput), CompositorView (single-layer first)

**Research flag:** Standard patterns, no additional research needed — Apple docs and forums are authoritative and complete for this domain.

### Phase 2: Import + CompositorView + Fader

**Rationale:** The fader is the entire product differentiator. It must be built before saving sessions because there is nothing to validate without it. Import is the prerequisite for any recording — a reference video URL is required. CompositorView gets upgraded to stack two layers and expose setVideoBlend for the fader.

**Delivers:** Complete recording screen — import reference video, two-layer compositor, working DJ-fader (video opacity + audio volume cross-fade), the core Spikzit interaction.

**Features addressed:** "Import reference video from Camera Roll," "DJ-fader video blend," "DJ-fader audio blend"

**Stack elements used:** PhotosUI SwiftUI PhotosPicker, AVPlayerLayer, AVCaptureVideoPreviewLayer, CALayer.opacity (GPU composited, zero CPU), AVPlayer.volume for audio fader

**Pitfalls to prevent:** Do not use AVMutableVideoComposition here — CALayer opacity only for live fader. AVKit VideoPlayer is off-limits for this screen.

**Research flag:** The CALayer opacity approach is well-documented. No additional research needed. If fader smoothness is inadequate, escalate to CoreImage compositor (not Metal — try CoreImage first).

### Phase 3: Persistence + Session History

**Rationale:** Once a recording is proven to work with correct audio and visual fader, sessions need to be saved and navigated. SwiftData PracticeSession model must include the sync timestamp offset captured in Phase 1 — this is the design-time dependency that prevents later refactoring.

**Delivers:** Session saved on recording stop (reference path + recording path + timestamp + sync offset); session history list with timestamps; session deletion with file cleanup.

**Features addressed:** "Save session," "Session history list"

**Architecture components:** SessionStore (SwiftData CRUD), FileVault (FileManager I/O), PracticeSession @Model (id, createdAt, duration, referenceFilename, recordingFilename, syncOffsetSeconds)

**Pitfalls to prevent:** Store relative filenames only in SwiftData (never absolute paths — container UUID changes on reinstall). FileVault is the only component that calls FileManager.

**Research flag:** Standard SwiftData patterns. No additional research needed.

### Phase 4: Review Session + Dual-Player Sync

**Rationale:** The training loop is incomplete without review. ReviewViewModel reuses PlaybackEngine and CompositorView — no new engines needed. The dual-player sync strategy (periodic time observer at 0.1s granularity using the stored offset) is the key implementation detail.

**Delivers:** Session review screen with the same fader UI operating on stored recordings; dual-player time sync; the full practice-review-practice loop.

**Features addressed:** "Review past sessions with the same fader UI"

**Architecture components:** ReviewViewModel (two PlaybackEngine instances from stored URLs), same CompositorView and FaderControlView reused

**Pitfalls to prevent:** Use the sync offset captured in Phase 1 (not recordedDuration) to align players. Verify with the clap-sync test: record a clap at frame 0 of the reference video, step through frames in review, clap must align within one frame.

**Research flag:** Dual AVPlayer sync is a known pattern with established solutions (periodic time observer). No additional research needed.

### Phase 5: Audio Routing + Edge Cases + App Store Readiness

**Rationale:** Edge cases do not block the happy path but block submission. Permission denial states, background interruption handling, storage accounting, and privacy manifest are required for App Store approval. These ship last because they add no user-visible feature value until the core loop is validated.

**Delivers:** Graceful permission denied states (camera, microphone, photo library); headphone unplug mid-session handling (pause + alert); background/lock screen safe recording stop; storage usage visible per session; privacy manifest (NSCameraUsageDescription, NSMicrophoneUsageDescription with specific purpose strings); all "Looks Done But Isn't" checklist items passing.

**Features addressed:** "Microphone and camera permission handling with clear explanations"

**Pitfalls to prevent:** Privacy manifest missing (App Store rejection); generic permission strings (Apple rejection); no headphone route check on launch (acoustic bleed silently corrupts all recordings on speaker); audio session not resumed after phone call.

**Research flag:** No additional research needed — Apple's App Store Review Guidelines and documentation are authoritative.

### Phase 6: v1.x Enhancements (Post-Validation)

**Rationale:** Add after the core loop is validated with real users. These features have clear demand signals from competitor reviews (segment looping is TubeShad's most praised feature) but do not belong in the initial ship.

**Delivers:** Playback speed control (0.5x / 0.75x / 1x via AVPlayer.rate); segment looping (in/out points on timeline); session rename and notes; export to Camera Roll (PHPhotoLibrary + AVAssetExportSession if blended export is wanted, or direct file copy if unblended).

**Research flag:** Playback speed and segment looping are standard AVPlayer patterns. Export via PHPhotoLibrary is well-documented. No research needed unless blended video export is required, in which case AVMutableComposition + AVAssetExportSession path needs a focused research spike.

### Phase Ordering Rationale

- AudioSessionManager before any UI because incorrect audio configuration is a silent failure that corrupts everything downstream and is hard to diagnose after the fact
- Import before recording because a reference video URL is the required input to start any session
- Fader before save because there is nothing to validate without the core differentiator working
- Save before review because review requires stored session files
- Review reuses engines from Phases 1-2 — no new AVFoundation work needed
- Edge cases and App Store readiness last because they add submission compliance, not user-visible features

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (dual-player sync):** If the periodic time observer approach produces visible sync drift at high playback speeds or on older devices, investigate AVSynchronizedLayer as an alternative. Low probability but worth flagging.
- **Phase 6 (blended video export):** If users request the ability to save a blended video to Camera Roll, AVMutableComposition + AVAssetExportSession needs a focused research spike — this is a different pipeline from live fader blending.

Phases with standard patterns (no research needed):
- **Phase 1:** AVFoundation simultaneous playback + capture is extremely well-documented; Apple Developer Forums have canonical answers for every pitfall identified.
- **Phase 2:** CALayer opacity fader is the recommended Apple pattern; PHPickerViewController is straightforward.
- **Phase 3:** SwiftData with @Model and @Query is standard greenfield pattern for iOS 17+.
- **Phase 5:** App Store privacy manifest and permission handling are fully documented by Apple.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations are Apple system frameworks; version compatibility verified against official docs; iOS 18 adoption data from TelemetryDeck (88%+ confirms iOS 17 minimum) |
| Features | MEDIUM | Competitor feature sets verified via official sites and App Store listings; user expectations inferred from reviews and category norms; no direct user interviews to confirm demand signals |
| Architecture | HIGH | Core patterns (CALayer opacity, dedicated session queue, single AVAudioSession) verified through official Apple docs and Apple Developer Forums; anti-patterns verified through developer post-mortems |
| Pitfalls | HIGH | Most pitfalls verified through Apple Developer Forums threads and official Apple documentation; AVCaptureMovieFileOutput recordedDuration inaccuracy verified via 2025 developer post-mortem |

**Overall confidence:** HIGH

### Gaps to Address

- **Sync offset tolerance:** The ±0.1s dual-player sync tolerance is documented as acceptable for speech shadowing review, but the exact user perception threshold for acceptable sync has not been user-tested. Validate during Phase 4 with real recordings; tighten if users perceive drift.
- **Front camera quality on oldest supported hardware:** Phase 1 should include a performance benchmark on the oldest supported device (iPhone with iOS 17 minimum). If a 5-minute session with two video pipelines causes memory warnings or thermal throttling, session preset may need to drop to `.medium`.
- **AirPods mic routing ambiguity:** The research confirms AirPods use HFP profile for mic input (which reduces audio quality). The user experience of "hearing the reference in A2DP quality while the mic is in HFP mode" needs validation with a physical device before shipping. AirPods mic quality in `.playAndRecord` mode may be noticeably worse than expected by the user.
- **Storage warning UX:** No specific threshold was researched for when to warn users about storage. Use 500MB free as an initial sentinel (based on 200-500MB per session pair estimate); validate in Phase 3 and adjust based on actual observed file sizes.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: AVCaptureSession, AVAudioSession, AVPlayerLayer, AVCaptureVideoPreviewLayer, CALayer opacity, AVCaptureMovieFileOutput, PHPickerViewController, AVMutableVideoCompositionLayerInstruction
- Apple Developer Forums: thread/61594 (AVCaptureSession + AVAudioSession), thread/742022 (recording sync), thread/73800 (MovieFileOutput vs AssetWriter), thread/61406 (background recording)
- WWDC 2019/2023/2025: multi-camera capture, camera experience, audio recording capabilities
- TelemetryDeck iOS Version Market Share 2026: iOS 18 at 88%+ adoption (confirms iOS 17 minimum)

### Secondary (MEDIUM confidence)
- ShadowSpeak, Speak Pro, TubeShad, Orai, Speeko, SpeakVibe — App Store listings and official sites for competitor feature analysis
- twocentstudios.com (2025): AVCaptureMovieFileOutput recordedDuration inaccuracy — developer post-mortem with reproduction details
- objc.io: Capturing Video on iOS — established patterns
- Kodeco: camera app with SwiftUI, AVFoundation overlays
- Atomic Object: Bluetooth audio sessions in Swift
- byby.dev: SwiftData vs CoreData analysis for greenfield iOS 17+ projects

### Tertiary (LOW confidence)
- banuba.com: AVMutableComposition overlay pattern — general confirmation, not Spikzit-specific
- Simform/Medium: AVAudioSession input device management — community analysis, cross-referenced with Apple docs

---
*Research completed: 2026-03-25*
*Ready for roadmap: yes*
