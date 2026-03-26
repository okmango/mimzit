---
phase: 02-recording-fader-view-modes
plan: 01
subsystem: engines
tags: [avfoundation, avcapturesession, avplayer, avplayerlayer, caLayer, swiftui, ios]

# Dependency graph
requires:
  - phase: 01-foundation-import-transcription
    provides: AudioSessionManager (.playAndRecord config), FileVault (static method pattern), ReferenceContent (ContentType enum)
provides:
  - CaptureEngine: AVCaptureSession lifecycle with FOUND-02 compliance, front camera + mic, movie file output, previewLayer
  - PlaybackEngine: AVPlayer with AVPlayerLayer, volume control for audio fader, auto-looping
  - ViewMode: 4 recording modes with layer visibility and fader semantics
  - Theme recording colors: 10 constants matching UI-SPEC (recordActive, faderTrack, overlayPanel, etc.)
  - FileVault recordings extension: recordingsDirectory, recordingURL, cleanupOldRecordings
affects:
  - 02-02 (CompositorView and RecordingViewModel consume CaptureEngine and PlaybackEngine)
  - 02-03 (full recording screen consumes all engines, ViewMode, and Theme recording colors)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Observable @MainActor final class on a dedicated sessionQueue (DispatchQueue) for AVCaptureSession — all session mutations dispatched off main thread"
    - "AVCaptureSession.automaticallyConfiguresApplicationAudioSession = false set inside beginConfiguration() before any inputs"
    - "PlaybackEngine loop via NotificationCenter AVPlayerItemDidPlayToEndTime + Task @MainActor to seek/play"
    - "ViewMode enum with computed Bool properties for layer visibility and fader semantics — single source of truth for recording screen state"
    - "FileVault static enum pattern extended with a recordings sub-directory alongside existing content sub-directory"

key-files:
  created:
    - Mimzit/Engines/CaptureEngine.swift
    - Mimzit/Engines/PlaybackEngine.swift
    - Mimzit/Models/ViewMode.swift
  modified:
    - Mimzit/Shared/Theme.swift
    - Mimzit/Services/FileVault.swift
    - Mimzit.xcodeproj/project.pbxproj

key-decisions:
  - "CaptureEngine is @Observable @MainActor but dispatches all session work to a serial sessionQueue — main actor isolation for SwiftUI observation without blocking main thread"
  - "PlaybackEngine deinit cannot access main actor properties in Swift 6 strict concurrency; observer cleanup handled in setupLoop() re-registration (old observer removed before new one added)"
  - "VideoRotationAngle (iOS 17+) used for portrait recording orientation on movie output video connection"

patterns-established:
  - "Pattern: Engines/ directory for AVFoundation wrapper classes (not in Services/ which is for networking/storage)"
  - "Pattern: ViewMode enum as single source of truth for layer visibility — no boolean flags scattered across ViewModel"

requirements-completed: [REC-01, REC-02, REC-04, REC-05, FADER-02, FADER-04]

# Metrics
duration: 12min
completed: 2026-03-26
---

# Phase 2 Plan 1: Engine Layer and Type Contracts Summary

**CaptureEngine (AVCaptureSession on serial queue with FOUND-02 compliance) + PlaybackEngine (AVPlayer with volume and auto-loop) + ViewMode enum (4 modes with layer visibility semantics) + Theme/FileVault recording extensions — all 5 files compile**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-03-26T22:12:55Z
- **Completed:** 2026-03-26T22:25:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- CaptureEngine manages AVCaptureSession lifecycle on a dedicated serial queue, exposes previewLayer and movie recording, sets `automaticallyConfiguresApplicationAudioSession = false` (FOUND-02) inside `beginConfiguration()` before any inputs
- PlaybackEngine wraps AVPlayer with volume binding for audio fader (FADER-02), exposes AVPlayerLayer with `.resizeAspectFill`, auto-loops via `AVPlayerItemDidPlayToEndTime` notification
- ViewMode enum defines 4 modes with `showsReferenceLayer`, `showsCameraLayer`, `showsTextOverlay`, `faderControlsTextOpacity`, and `videoFaderRightLabel` — single source of truth for recording screen layer logic
- Theme extended with 10 recording-specific color constants matching UI-SPEC exact values
- FileVault extended with `recordingsDirectory`, `recordingURL`, and `cleanupOldRecordings` for Phase 2 temporary file management

## Task Commits

Each task was committed atomically:

1. **Task 1: CaptureEngine, PlaybackEngine, and ViewMode enum** - `3ab0156` (feat)
2. **Task 2: Theme recording colors and FileVault recordings extension** - `1d2b05e` (feat)

## Files Created/Modified
- `Mimzit/Engines/CaptureEngine.swift` — AVCaptureSession lifecycle, front camera + mic, movie file output, previewLayer, syncTimestamp
- `Mimzit/Engines/PlaybackEngine.swift` — AVPlayer wrapper with AVPlayerLayer, volume binding, auto-loop
- `Mimzit/Models/ViewMode.swift` — 4-case enum with layer visibility and fader semantic computed properties
- `Mimzit/Shared/Theme.swift` — added 10 recording UI color constants (recordActive, faderTrack, overlayPanel, etc.)
- `Mimzit/Services/FileVault.swift` — added recordingsDirectory, recordingURL(filename:), cleanupOldRecordings()
- `Mimzit.xcodeproj/project.pbxproj` — added Engines/ group with CaptureEngine + PlaybackEngine; ViewMode.swift to Models group

## Decisions Made
- CaptureEngine uses `@Observable @MainActor` for SwiftUI observation but dispatches all AVCaptureSession mutations to `sessionQueue` (DispatchQueue) — this is the correct pattern for thread-safe session management
- Swift 6 strict concurrency: `deinit` cannot access main actor properties, so PlaybackEngine's loop observer is removed and re-registered in `setupLoop()` on each `load()` call rather than in `deinit`
- `videoRotationAngle = 90` set on the movie output video connection for portrait recording (iOS 17+ API, replaces deprecated `videoOrientation`)
- Simulator name mismatch: plan specified "iPhone 16 Pro" but only iOS 26.2 simulators are available; used "iPhone 17 Pro" instead — no code impact

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Swift 6 strict concurrency errors in PlaybackEngine**
- **Found during:** Task 1 (build verification)
- **Issue:** `deinit` accessing main actor-isolated `loopObserver` property caused compile error; loop notification closure accessing main actor properties from non-isolated context caused warning
- **Fix:** Removed `deinit` cleanup (replaced with `cleanupObserver()` stub); wrapped loop notification callback in `Task { @MainActor }` to properly hop to main actor
- **Files modified:** Mimzit/Engines/PlaybackEngine.swift
- **Verification:** xcodebuild BUILD SUCCEEDED
- **Committed in:** 3ab0156 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — compile-time bug)
**Impact on plan:** Necessary for correct Swift 6 concurrency behavior. No scope creep.

## Issues Encountered
- Build destination "iPhone 16 Pro" not available in installed Xcode (iOS 26.2 simulators only); used "iPhone 17 Pro" — no impact on build output

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 5 engine/model/shared files compile and are registered in the Xcode project
- CaptureEngine and PlaybackEngine are ready for consumption by CompositorView (02-02)
- ViewMode is ready for RecordingViewModel and RecordingView (02-02, 02-03)
- Theme recording colors and FileVault recordings extension are ready for any Phase 2 plan
- No blockers for 02-02

---
*Phase: 02-recording-fader-view-modes*
*Completed: 2026-03-26*
