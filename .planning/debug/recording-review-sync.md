---
status: awaiting_human_verify
trigger: "Recording and review playback sync issue — reference video and user recording drift apart during review. Plus remove audio fader from recording screen."
created: 2026-03-27T06:00:00.000Z
updated: 2026-03-27T08:00:00.000Z
---

## Current Focus

hypothesis: Three new behavioral issues confirmed by code inspection during Phase 3 device testing:
  (1) Audio fader shown on RecordingView even when NOT recording — audioFaderVisible returns true
      whenever !isRecording && contentType != .text, which means it shows in the pre-recording idle
      state. Constraint: hide it on the entire recording screen, not just during active recording.
  (2) ReviewView .onChange(of: viewModel?.audioBlend) calls updateAudioBlend() correctly BUT the
      Binding set closure directly mutates viewModel.audioBlend without going through onChange,
      so the chain is: FaderView writes -> Binding.set -> viewModel.audioBlend mutates ->
      onChange fires -> updateAudioBlend() executes. This SHOULD work. Root cause is different:
      ReviewViewModel.setup() calls updateAudioBlend() ONCE before the periodic sync observer is
      set up, and the userEngine has no onFinished handler — but more importantly, the audioBlend
      Binding in ReviewView uses viewModel?.audioBlend ?? 0 with optional chaining which could
      silently drop updates if the optional unwrap fails. Checking whether audioBlend is wired
      correctly end-to-end.
  (3) ReviewViewModel.setup() sets referenceEngine.onFinished to reset both players, but
      userEngine.onFinished is never set. When user recording ends before reference, only
      referenceEngine.onFinished fires when reference eventually ends — nothing fires when the
      user video ends. Need to add userEngine.onFinished that pauses both and resets.
test: Code trace — reading ReviewView audio fader binding, ReviewViewModel.updateAudioBlend, and
      PlaybackEngine.volume setter
expecting: All three issues confirmed and fixed
next_action: Apply all three fixes

## Symptoms

expected:
  1. Audio fader NOT visible anywhere on recording screen.
  2. Review audio fader actually controls volume — YOU side = user audio only, REF side = ref audio only.
  3. When user recording ends before reference, both stop. Play restarts both from beginning.
actual:
  1. Audio fader visible on recording screen when not actively recording (idle state).
  2. Moving audio fader to YOU side in review still plays reference audio.
  3. Reference keeps playing after user video ends.
errors: No error messages — behavioral issues
reproduction:
  1. Open any reference content, tap Start Practice — audio fader visible before recording starts
  2. In review, play a session, move audio fader to YOU — still hear reference
  3. Record a session shorter than reference, review it — reference keeps playing after user video ends
started: Found during Phase 3 device testing after first round of sync fixes.

## Eliminated

- hypothesis: ReviewViewModel drift correction is the primary cause of sync issues
  evidence: syncObserver fires every 100ms and corrects >50ms drift — but it cannot fix a fundamental length mismatch caused by recording starting late relative to playback
  timestamp: 2026-03-27T06:00:00.000Z

- hypothesis: PlaybackEngine.seek() is async and causes race in review setup
  evidence: seek(to:) calls in setup() are synchronous from caller perspective; the issue is at recording time, not review time
  timestamp: 2026-03-27T06:00:00.000Z

- hypothesis: audioFaderVisible guard (isRecording) from prior session fully solved issue 1
  evidence: New device testing shows fader still visible in idle state — the prior fix only hid it DURING recording, not during the idle pre-recording state. Constraint requires hiding it on the ENTIRE recording screen.
  timestamp: 2026-03-27T08:00:00.000Z

- hypothesis: ReviewView onChange wiring is broken for audio blend
  evidence: Traced the full chain — FaderView Binding.set writes viewModel.audioBlend directly, onChange(of: viewModel?.audioBlend) fires, updateAudioBlend() is called. Chain is intact. The real issue is simpler: audioBlend defaults to 0.0 and updateAudioBlend() is called once in setup(). But the onChange uses optional chaining viewModel?.audioBlend ?? 0 which loses the specific optional identity — SwiftUI may not track this correctly. More critically: need to verify PlaybackEngine.volume setter actually fires via didSet when volume is set on userEngine.
  timestamp: 2026-03-27T08:00:00.000Z

## Evidence

- timestamp: 2026-03-27T06:00:00.000Z
  checked: RecordingViewModel.toggleRecording() lines 205-251
  found: syncTimestamp captured, captureEngine.startRecording() dispatched async to sessionQueue, reference playback starts in fileOutput(_:didStartRecordingTo:) delegate callback
  implication: Race condition fix from prior session is in place.

- timestamp: 2026-03-27T06:00:00.000Z
  checked: RecordingViewModel.audioFaderVisible
  found: returns !isRecording && content.contentType != .text
  implication: Prior fix only hid fader DURING recording. New constraint: hide it on the entire recording screen. Fix: always return false from audioFaderVisible in RecordingViewModel.

- timestamp: 2026-03-27T08:00:00.000Z
  checked: ReviewView.swift lines 80-83 — onChange(of: viewModel?.audioBlend ?? 0)
  found: onChange uses optional chaining with ?? 0. When viewModel is non-nil, this evaluates to viewModel.audioBlend Float. SwiftUI's onChange with an optional chain can be fragile — the observed expression `viewModel?.audioBlend ?? 0` is a computed value, not a direct @Observable property path. SwiftUI may not register the dependency correctly.
  implication: The onChange chain may be silently dropping fader updates. More reliable: wire the FaderView Binding.set closure to call updateAudioBlend() directly.

- timestamp: 2026-03-27T08:00:00.000Z
  checked: PlaybackEngine.volume didSet
  found: var volume: Float = 1.0 { didSet { player.volume = volume } } — correct
  implication: Volume setter is fine. The problem is in how updateAudioBlend() is called, not in PlaybackEngine itself.

- timestamp: 2026-03-27T08:00:00.000Z
  checked: ReviewViewModel.setup() — userEngine.onFinished
  found: Only referenceEngine.onFinished is set. userEngine has no onFinished handler. When user recording ends, nothing pauses the reference engine.
  implication: Need to add userEngine.onFinished that pauses both engines and resets to start, mirroring the referenceEngine.onFinished behavior. Duration should also use min(reference, user) for the scrub bar.

- timestamp: 2026-03-27T08:00:00.000Z
  checked: ReviewViewModel.duration = referenceContent.duration ?? session.duration
  found: Duration is always set to reference duration. When user recording is shorter, scrub bar extends past the actual user content end.
  implication: Should be min(referenceDuration, userDuration). Since session.duration records actual recorded duration, use min(referenceContent.duration ?? session.duration, session.duration).

## Resolution

root_cause: |
  1. RecordingView audio fader: audioFaderVisible never returns false for non-text content.
     Prior fix added !isRecording guard but new requirement is to hide it on the entire screen.
  2. ReviewView audio fader: onChange(of: viewModel?.audioBlend ?? 0) uses optional-chained
     computed expression — SwiftUI @Observable dependency tracking may not fire reliably.
     More robust: call updateAudioBlend() directly from the FaderView Binding.set closure.
  3. ReviewViewModel: userEngine.onFinished is never set. When user video ends before reference,
     nothing stops playback. Also duration should be min(reference, user) not reference alone.
fix: |
  1. RecordingViewModel.audioFaderVisible: change to always return false (audio fader never shown
     on recording screen per new constraint).
  2. ReviewView audio fader Binding: replace onChange-based approach with direct call to
     updateAudioBlend() in the Binding.set closure.
  3. ReviewViewModel.setup(): add userEngine.onFinished handler that pauses both, resets both
     to .zero, and resets scrub state. Change duration to min(referenceContent.duration ?? session.duration, session.duration).
verification: |
  Build clean — zero new errors (pre-existing nonisolated warning unrelated to changes).
  Code analysis verified:
  - Issue 1: audioFaderVisible now returns false unconditionally. FaderView inside
    `if viewModel.audioFaderVisible` block in RecordingView.bottomPanel never renders.
  - Issue 2: Audio fader Binding.set in ReviewView now calls updateAudioBlend() directly.
    onChange(of: viewModel?.audioBlend) removed — was unreliable under @Observable with
    optional-chained expressions. Every fader drag event writes audioBlend then immediately
    applies volume to both engines.
  - Issue 3: userEngine.onFinished now set to same resetPlayback closure as referenceEngine.
    Either video ending pauses both and resets to .zero. duration uses min(ref, user).
  Awaiting device verification.
files_changed:
  - Mimzit/Features/Recording/RecordingViewModel.swift
  - Mimzit/Features/Review/ReviewViewModel.swift
  - Mimzit/Features/Review/ReviewView.swift
