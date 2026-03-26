# Phase 2: Recording + Fader + View Modes - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can play reference content while simultaneously recording themselves via front camera, blending video and audio with a DJ-fader UI, switching between 4 view modes during recording, and using a teleprompter for text-only content. This is the product differentiator — the one thing no existing iOS app does.

</domain>

<decisions>
## Implementation Decisions

### Recording Screen Layout
- **D-01:** Full-screen video with overlay controls. Reference video fills entire screen, camera preview overlays on top (opacity via fader). Controls float as semi-transparent overlays at bottom. Maximizes video real estate on iPhone.
- **D-02:** Navigate to recording via "Start Practice" button on ContentDetailView (from Phase 1). Full-screen recording view pushes in.
- **D-03:** Record button: center bottom, large circular red. Tap to start/stop. Pulsing red when recording. Classic camera app pattern, thumb-reachable.
- **D-04:** Auto-hide controls after 3 seconds during recording. Tap anywhere to show. Faders stay visible while being actively dragged.

### Fader Interaction Design
- **D-05:** Video fader: horizontal slider above record button. Left = reference only, center = blended overlay, right = camera only. Uses CALayer opacity for GPU-composited blending (zero CPU cost, per CLAUDE.md architecture).
- **D-06:** Audio fader: separate smaller horizontal slider below or beside video fader. Controls AVPlayer.volume (reference) inversely proportional to position. Independent from video fader.
- **D-07:** Two separate faders — video and audio are independently controlled. User can hear reference while seeing only themselves, or vice versa. Matches FADER-01 + FADER-02 requirements.
- **D-08:** Default positions: Video starts at center (50/50 blend), Audio starts at reference-only (left). User immediately sees the comparison and hears what to mimic.
- **D-09:** Haptic feedback at 0%, 50%, and 100% positions on both faders. UIImpactFeedbackGenerator light tap. Helps find key blend points without looking.

### View Mode Switching
- **D-10:** Floating pill-shaped segmented control at top of screen with 4 modes: Ref | Cam | Blend | Text. Tap to switch instantly. Semi-transparent background. Compact, discoverable, one-tap access.
- **D-11:** In text overlay mode, the video fader controls text opacity over the video instead of camera/reference blend. Audio fader stays the same. Fader adapts to active view mode context.
- **D-12:** Text overlay mode (VIEW-02): shows scrolling transcript on top of reference video with semi-transparent background. Toggle on/off per VIEW-03.

### Teleprompter Behavior
- **D-13:** Text-only mode: auto-scroll with adjustable speed. Speed control via small slider or +/- buttons. Scrolling starts when recording starts, pauses when recording pauses.
- **D-14:** Teleprompter visual style: dark/black background, large white text, current line highlighted, text centered horizontally. Classic teleprompter look optimized for readability while speaking.
- **D-15:** Camera records simultaneously in teleprompter mode (user is recorded while reading the script). REC-06 fulfilled.

### Carried Forward from Phase 1
- **D-16:** AVCaptureSession.automaticallyConfiguresApplicationAudioSession = false — MUST be set when creating AVCaptureSession (FOUND-02, deferred from Phase 1).
- **D-17:** AudioSessionManager already configured with .playAndRecord mode from Phase 1. No reconfiguration needed.

### Claude's Discretion
- CaptureEngine implementation details (AVCaptureSession setup, device configuration, output handling)
- Exact animation timing for control auto-hide/show
- Fader thumb size and visual design details
- View mode transition animations
- Teleprompter font size and line spacing specifics
- How to handle recording file naming and temporary storage

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Codebase (Integration Points)
- `Mimzit/Services/AudioSessionManager.swift` — AVAudioSession config already done; FOUND-02 comment for Phase 2
- `Mimzit/Models/ReferenceContent.swift` — SwiftData model with contentType, filename, transcript fields
- `Mimzit/Services/FileVault.swift` — File storage/retrieval for reference content and recordings
- `Mimzit/Features/Import/ContentDetailView.swift` — "Start Practice" button to wire up
- `Mimzit/Shared/Theme.swift` — Semantic color system to extend for recording UI
- `Mimzit/App/ContentView.swift` — Tab-based navigation root

### Architecture Documentation
- `.planning/research/ARCHITECTURE.md` — AVFoundation architecture notes, CALayer opacity for live fader, audio routing
- `CLAUDE.md` — Stack decisions, AVFoundation patterns, what NOT to use (ReplayKit, AVKit VideoPlayer for recording screen)

### Sibling Project Patterns
- `../carufus_whozit/Whozit/` — UI/UX quality reference
- `../sezit/` — OpenAI patterns (already integrated in Phase 1)

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints
- `.planning/REQUIREMENTS.md` — REC-01 through FADER-04 requirement details
- `.planning/ROADMAP.md` — Phase 2 goal and success criteria
- `.planning/phases/01-foundation-import-transcription/01-CONTEXT.md` — Phase 1 decisions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **AudioSessionManager:** Already configured for .playAndRecord. Phase 2 adds AVCaptureSession with auto-config disabled.
- **FileVault:** Can store recording output files alongside reference content
- **ReferenceContent model:** Has contentType enum (video/audio/text), filename, transcript — all needed for recording screen to know what to display
- **Theme.swift:** Extend with recording-specific colors (record red, fader track colors)
- **ContentDetailView:** Has "Start Practice" button ready to wire to recording screen

### Established Patterns
- **@Observable @MainActor services:** TranscriptionService pattern for new CaptureEngine/RecordingService
- **UIViewRepresentable:** VideoPicker wraps PHPickerViewController — same pattern needed for AVPlayerLayer + AVCaptureVideoPreviewLayer
- **Feature folders:** `Mimzit/Features/Recording/` for new recording views

### Integration Points
- **ContentDetailView → RecordingView:** "Start Practice" navigates to full-screen recording
- **AVAudioSession:** Already active, recording screen inherits the session
- **FileVault:** Recording output saved through FileVault, path stored in future Session model (Phase 3)
- **Tab bar:** Should hide during full-screen recording

</code_context>

<specifics>
## Specific Ideas

- The fader interaction is the product differentiator — it must feel smooth and responsive at 60fps
- CALayer opacity approach (from CLAUDE.md) is the cheapest path for live video blending
- Two-fader design (video + audio independent) is critical for the use case — practicing speakers need to hear reference audio while seeing only themselves
- Auto-hide controls during recording keeps focus on the practice, not the UI
- Teleprompter should feel like a real teleprompter — large text, dark background, auto-scroll synced to recording

</specifics>

<deferred>
## Deferred Ideas

- Session saving (Phase 3) — recording output is temporary until Phase 3 adds persistence
- Review playback with fader (Phase 3) — same fader UI reused for review
- Playback speed control (v2 — PLAY-01)
- Loop in/out points (v2 — PLAY-02)

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-recording-fader-view-modes*
*Context gathered: 2026-03-26*
