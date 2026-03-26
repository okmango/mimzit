# Roadmap: Mimzit

## Overview

Three phases that each deliver a testable slice of the product. Phase 1 builds the foundation that everything depends on — correct AVAudioSession configuration, content import pipeline, and AI transcription. Phase 2 builds the product differentiator — simultaneous reference playback and front-camera recording with the DJ-fader UI and all view modes. Phase 3 closes the training loop — session persistence, history, and review playback using the same fader UI from Phase 2.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation + Import + Transcription** - AVAudioSession setup, content import pipeline, Whisper AI transcription
- [ ] **Phase 2: Recording + Fader + View Modes** - Simultaneous playback and recording with DJ-fader UI and switchable view modes
- [ ] **Phase 3: Sessions + Review** - Save sessions, view history, and review past recordings with the same fader UI

## Phase Details

### Phase 1: Foundation + Import + Transcription
**Goal**: Users can import reference content and get a transcript ready before any recording session begins
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, IMPORT-01, IMPORT-02, IMPORT-03, IMPORT-04, IMPORT-05, TRANS-01, TRANS-02, TRANS-03, TRANS-04
**Success Criteria** (what must be TRUE):
  1. User can import a reference video, audio file, or typed script and see it appear in the app ready for use
  2. User can request AI transcription of an imported video or audio file and see the resulting text saved alongside the content
  3. App correctly configures audio routing before any media starts (no silent overwrite by AVCaptureSession)
  4. App detects missing headphones and warns user before they attempt to record
  5. OpenAI API key can be stored and retrieved securely; app falls back to on-device recognition when no key is present
**Plans:** 1/3 plans executed

Plans:
- [x] 01-01-PLAN.md — Project scaffold, data models, and all foundation/transcription services
- [x] 01-02-PLAN.md — Content library UI, all import flows, content detail/preview, and Settings
- [ ] 01-03-PLAN.md — Transcription UI wiring, API key lazy prompt, and Phase 1 verification checkpoint

### Phase 2: Recording + Fader + View Modes
**Goal**: Users can practice delivery alongside a reference in real time, blending video and audio with a DJ-fader
**Depends on**: Phase 1
**Requirements**: REC-01, REC-02, REC-03, REC-04, REC-05, REC-06, VIEW-01, VIEW-02, VIEW-03, FADER-01, FADER-02, FADER-03, FADER-04
**Success Criteria** (what must be TRUE):
  1. User can start recording themselves while reference video or audio plays simultaneously without either stream cutting out
  2. User can slide the video fader and see the displayed image blend smoothly between reference video and camera preview at 60fps
  3. User can slide the audio fader and hear the blend shift between reference audio and their own voice
  4. User can switch view modes (reference only, camera only, blended overlay, text overlay) during an active recording session
  5. In text-only mode, the teleprompter scrolls automatically and the user's recording starts and stops cleanly
**Plans**: TBD

### Phase 3: Sessions + Review
**Goal**: Users can save practice sessions and review any past session with the full fader UI to compare their delivery to the reference
**Depends on**: Phase 2
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04, REV-01, REV-02, REV-03, REV-04
**Success Criteria** (what must be TRUE):
  1. A completed recording session is saved automatically and appears in the session history list with a timestamp
  2. User can delete a session from history and the associated files are removed from device storage
  3. User can open any past session and review it with the same video and audio faders used during recording
  4. Reference video and user recording play in sync during review (within one-frame drift for speech comparison)
  5. User can pause and scrub through review playback and see the fader blend update at the scrubbed position
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Import + Transcription | 1/3 | In Progress|  |
| 2. Recording + Fader + View Modes | 0/? | Not started | - |
| 3. Sessions + Review | 0/? | Not started | - |
