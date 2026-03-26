# Requirements: Mimzit

**Defined:** 2026-03-25
**Core Value:** Users can record themselves alongside a reference speaker video and visually compare their delivery side-by-side

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation

- [x] **FOUND-01**: App configures AVAudioSession in .playAndRecord mode before any media engine starts
- [x] **FOUND-02**: App disables AVCaptureSession.automaticallyConfiguresApplicationAudioSession to prevent silent audio config overwrite
- [x] **FOUND-03**: App detects headphone/AirPods connection and warns user if no headphones detected before recording
- [x] **FOUND-04**: App requests camera and microphone permissions with clear explanations before first use
- [x] **FOUND-05**: OpenAI API key stored securely in iOS Keychain (reuse sezit KeychainHelper pattern)

### Content Import

- [ ] **IMPORT-01**: User can import a reference video from Camera Roll via system picker (mp4/mov only)
- [ ] **IMPORT-02**: User can import an audio-only file from Files app (m4a/mp3)
- [ ] **IMPORT-03**: User can paste or type text as a reference script (text-only mode)
- [ ] **IMPORT-04**: Imported content is stored locally in app sandbox with metadata (type: video/audio/text)
- [ ] **IMPORT-05**: User can preview imported reference content before starting a practice session

### Transcription

- [x] **TRANS-01**: User can request AI transcription of reference video/audio via OpenAI Whisper API
- [x] **TRANS-02**: Audio is preprocessed before sending to Whisper (silence removal + 1.5x speedup, reuse sezit AudioPreprocessor pattern)
- [x] **TRANS-03**: Transcription text is saved alongside the reference content as synchronized transcript
- [ ] **TRANS-04**: Fallback to on-device SFSpeechRecognizer when no API key is configured (reuse digzit fallback pattern)

### Recording

- [ ] **REC-01**: User can play reference content (video/audio/text) while simultaneously recording themselves via front camera
- [ ] **REC-02**: Reference audio plays through headphones/AirPods while mic captures user's voice without bleed
- [ ] **REC-03**: User can see live camera preview overlaid on reference video during recording
- [ ] **REC-04**: User can start/stop recording with clear visual indicators
- [ ] **REC-05**: App captures sync timestamp at recording start for accurate review playback alignment
- [ ] **REC-06**: In text-only mode, text scrolls automatically during recording at configurable speed (teleprompter-style)

### View Modes

- [ ] **VIEW-01**: User can switch between view modes during recording: reference only, camera only, blended overlay, text overlay
- [ ] **VIEW-02**: Text overlay mode shows scrolling transcript on top of reference video (semi-transparent background)
- [ ] **VIEW-03**: When transcript is available for video/audio, user can toggle text overlay on/off during playback and recording

### Fader UI

- [ ] **FADER-01**: User can slide a video fader to blend between reference video (left), overlay (center), and self-only (right)
- [ ] **FADER-02**: User can slide an audio fader to blend between reference audio and their own recorded audio
- [ ] **FADER-03**: Fader UI runs at 60fps without dropped frames during both live recording and review playback
- [ ] **FADER-04**: Video blend uses CALayer opacity for GPU-composited performance

### Session Management

- [ ] **SESS-01**: User can save a completed practice session (reference + user recording pair + metadata)
- [ ] **SESS-02**: User can view a list of saved sessions sorted by date with timestamps
- [ ] **SESS-03**: User can delete saved sessions to free storage
- [ ] **SESS-04**: Session data persists across app launches (SwiftData, reuse digzit schema versioning pattern)

### Review

- [ ] **REV-01**: User can review any saved session with the same fader playback UI used during recording
- [ ] **REV-02**: Reference video and user recording play back in sync (within acceptable drift for speech comparison)
- [ ] **REV-03**: User can pause and scrub through review playback
- [ ] **REV-04**: User can compare different sessions of the same reference video to see progress over time

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Playback Controls

- **PLAY-01**: User can adjust playback speed of reference video (0.5x, 0.75x, 1x) during recording
- **PLAY-02**: User can set loop in/out points on reference video for drilling specific segments

### Organization

- **ORG-01**: User can rename sessions with custom titles
- **ORG-02**: User can add notes to sessions

### Export

- **EXP-01**: User can export recorded session to Camera Roll
- **EXP-02**: User can export blended side-by-side video via iOS share sheet

### AI Enhancement

- **AI-01**: GPT text transformation of transcripts (clean up, summarize, bullet points — reuse sezit GPTAPIClient pattern)
- **AI-02**: AI phoneme/pronunciation scoring against reference speaker
- **AI-03**: Waveform visualization during review playback
- **AI-04**: Word-level timestamp alignment in transcription for karaoke-style text highlighting

### Settings

- **SET-01**: User can configure OpenAI API key in settings
- **SET-02**: User can choose transcription language hint

## Out of Scope

| Feature | Reason |
|---------|--------|
| YouTube integration / embedding | Violates YouTube TOS; auth/ad issues; legal risk for App Store |
| Built-in curated speaker library | Content licensing complexity; user-supplied is more flexible |
| Cloud sync / iCloud backup | Adds server complexity; conflicts with fully-offline value prop |
| Social sharing / posting sessions | Privacy concerns (user's face+voice); moderation surface |
| Multi-device recording | AVFoundation doesn't support cross-device capture |
| Real-time AI feedback during recording | Thermal load + latency risk degrades core UX |
| Account / login system | Fully offline, no account is a competitive differentiator |
| Android version | iOS-first; evaluate after v1 validation |
| Video transcoding (avi, mkv, webm) | Adds 20MB+ FFmpeg dependency; mp4/mov covers 95%+ of use cases |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete |
| IMPORT-01 | Phase 1 | Pending |
| IMPORT-02 | Phase 1 | Pending |
| IMPORT-03 | Phase 1 | Pending |
| IMPORT-04 | Phase 1 | Pending |
| IMPORT-05 | Phase 1 | Pending |
| TRANS-01 | Phase 1 | Complete |
| TRANS-02 | Phase 1 | Complete |
| TRANS-03 | Phase 1 | Complete |
| TRANS-04 | Phase 1 | Pending |
| REC-01 | Phase 2 | Pending |
| REC-02 | Phase 2 | Pending |
| REC-03 | Phase 2 | Pending |
| REC-04 | Phase 2 | Pending |
| REC-05 | Phase 2 | Pending |
| REC-06 | Phase 2 | Pending |
| VIEW-01 | Phase 2 | Pending |
| VIEW-02 | Phase 2 | Pending |
| VIEW-03 | Phase 2 | Pending |
| FADER-01 | Phase 2 | Pending |
| FADER-02 | Phase 2 | Pending |
| FADER-03 | Phase 2 | Pending |
| FADER-04 | Phase 2 | Pending |
| SESS-01 | Phase 3 | Pending |
| SESS-02 | Phase 3 | Pending |
| SESS-03 | Phase 3 | Pending |
| SESS-04 | Phase 3 | Pending |
| REV-01 | Phase 3 | Pending |
| REV-02 | Phase 3 | Pending |
| REV-03 | Phase 3 | Pending |
| REV-04 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-25*
*Last updated: 2026-03-25 — traceability updated for 3-phase roadmap (TRANS moved to Phase 1)*
