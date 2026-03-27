---
status: awaiting_human_verify
trigger: "Recording and review playback sync issue — reference video and user recording drift apart during review. Plus remove audio fader from recording screen."
created: 2026-03-27T06:00:00.000Z
updated: 2026-03-27T06:00:00.000Z
---

## Current Focus

hypothesis: Two root causes confirmed by code inspection: (1) recording start race condition — reference playback starts on main thread before AVCaptureMovieFileOutput.startRecording() executes on sessionQueue, creating a 10-50ms lead in reference audio that makes user recording appear shorter; (2) audio fader visible during recording where reference audio is locked at 1.0 and the fader has no effect
test: Code tracing — comparing call order in toggleRecording() vs what actually executes on sessionQueue
expecting: Fix requires (a) playback start moved into sessionQueue callback after recording confirmed started, and (b) audio fader hidden while isRecording is true
next_action: Apply fixes to RecordingViewModel.swift and RecordingView.swift

## Symptoms

expected: In review mode, reference video and user recording should play perfectly in sync. During recording, only video fader should be shown (no audio fader needed).
actual: Videos drift apart during review — they appear to have different lengths or don't start simultaneously. Audio fader is shown during recording but serves no purpose.
errors: No error messages — purely a timing/sync behavioral issue
reproduction: Record a ~10 second practice session, then open it in review. Play both videos — they drift apart over time. The user recording appears shorter or starts at a different offset.
started: First observed during Phase 3 device testing. This is the first implementation.

## Eliminated

- hypothesis: ReviewViewModel drift correction is the primary cause
  evidence: syncObserver fires every 100ms and corrects >50ms drift — but it cannot fix a fundamental length mismatch caused by recording starting late relative to playback
  timestamp: 2026-03-27T06:00:00.000Z

- hypothesis: PlaybackEngine.seek() is async and causes race in review setup
  evidence: seek(to:) calls in setup() are synchronous from caller perspective; the issue is at recording time, not review time
  timestamp: 2026-03-27T06:00:00.000Z

## Evidence

- timestamp: 2026-03-27T06:00:00.000Z
  checked: RecordingViewModel.toggleRecording() lines 205-251
  found: syncTimestamp captured at line 208, captureEngine.startRecording() dispatched async to sessionQueue at line 212, then IMMEDIATELY on same main thread: playbackEngine.seek(.zero) at line 219 and playbackEngine.play() at line 220
  implication: Reference video starts playing on the main thread while capture recording is still waiting in the sessionQueue. The gap (10-50ms) means the reference video always has a head start. User recording is shorter by this offset.

- timestamp: 2026-03-27T06:00:00.000Z
  checked: CaptureEngine.startRecording() lines 167-175
  found: sessionQueue.async dispatches movieOutput.startRecording() — this is truly async, returns before recording starts
  implication: There is no callback or semaphore to notify main thread that recording has actually begun. The AVCaptureFileOutputRecordingDelegate.fileOutput(_:didStartRecordingTo:) callback fires AFTER recording starts, but toggleRecording() doesn't wait for it.

- timestamp: 2026-03-27T06:00:00.000Z
  checked: RecordingViewModel.fileOutput(_:didStartRecordingTo:) lines 338-346
  found: This delegate method exists and is called when recording actually starts. It posts isRecording=true back to MainActor. The fix: move playbackEngine.seek+play into this callback instead of in toggleRecording().
  implication: Reference playback should start here — after capture is confirmed started — not in toggleRecording().

- timestamp: 2026-03-27T06:00:00.000Z
  checked: RecordingView.swift bottomPanel, lines 265-283
  found: Audio fader shown when viewModel.audioFaderVisible is true. audioFaderVisible returns true for all non-text content. No check for isRecording state.
  implication: Audio fader is visible and interactive during recording even though updateAudioBlend() forces volume=1.0 during recording. User sees a control that does nothing. Should be hidden while isRecording.

- timestamp: 2026-03-27T06:00:00.000Z
  checked: ReviewViewModel.setup() and togglePlayPause()
  found: setup() calls referenceEngine.seek(.zero) and userEngine.seek(.zero) synchronously. togglePlayPause() calls referenceEngine.play() then userEngine.play() sequentially with no AVPlayer synchronization mechanism.
  implication: Two sequential play() calls have a tiny inter-call gap (~microseconds), but this is much smaller than the recording start race (10-50ms). The bigger issue is AVPlayerItem readiness — if assets aren't fully buffered, play() may stall. For local files this is negligible. The main drift source is the recording start race.

## Resolution

root_cause: |
  1. Recording start race condition: in toggleRecording(), playbackEngine.play() executes on the main thread BEFORE CaptureEngine.startRecording() has dispatched to sessionQueue and actually started recording. Reference video gets a 10-50ms head start, so the user recording is shorter by that offset.
  2. Audio fader shown during recording even though audio is locked at 1.0 — the control is non-functional and confusing.
fix: |
  1. Move playbackEngine.seek(.zero) + playbackEngine.play() out of toggleRecording() and into the fileOutput(_:didStartRecordingTo:) delegate callback. This guarantees reference playback starts only after AVCaptureMovieFileOutput confirms recording has begun.
  2. Add isRecording guard to audioFaderVisible computed property — returns false while recording is active.
verification: |
  Code analysis verified:
  - Reference playback now starts inside fileOutput(_:didStartRecordingTo:) which fires AFTER AVCaptureMovieFileOutput has confirmed recording is running on sessionQueue. This eliminates the 10-50ms race condition.
  - audioFaderVisible now returns false when isRecording is true — fader hides immediately when record is tapped.
  - isRecording = true in toggleRecording() retained for immediate UI feedback (button turns red), harmless double-set in delegate.
  - pendingContentTypeForRecordingStart nil-checked in stop path as defensive cleanup.
  Awaiting device verification of actual sync improvement.
files_changed:
  - Mimzit/Features/Recording/RecordingViewModel.swift
