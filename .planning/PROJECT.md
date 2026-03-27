# Mimzit

## What This Is

A native iOS app for speech shadowing with multi-content comparison. Users import reference content (video, audio, or text), record themselves mimicking the speaker's delivery in real-time, and review both recordings with a DJ-fader-style overlay UI that blends video and audio independently. Supports AI transcription (OpenAI Whisper) for text overlay on videos, switchable view modes during recording, and text-only teleprompter mode. Built for public speaking training, actor rehearsal, and presentation coaching.

## Core Value

Users can record themselves alongside a reference speaker video and visually compare their delivery side-by-side — the one thing no existing iOS app does.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Import reference content: video (mp4/mov), audio (m4a/mp3), or text
- [ ] AI transcription via OpenAI Whisper (with sezit-style audio preprocessing)
- [ ] On-device SFSpeechRecognizer fallback when no API key configured
- [ ] Play reference content while simultaneously recording user via front camera
- [ ] Switchable view modes: reference only, camera only, blended overlay, text overlay
- [ ] Text overlay on video (scrolling transcript, teleprompter-style)
- [ ] DJ-fader UI for video blend (reference ↔ overlay ↔ self-only)
- [ ] DJ-fader UI for audio blend (reference audio ↔ user audio)
- [ ] Save practice sessions (reference + recording pair)
- [ ] Session history with timestamps
- [ ] Review past sessions with the same fader playback UI
- [ ] AirPods/headphone audio routing (reference to headphones, mic captures user)
- [ ] API key stored in Keychain (reuse sezit/digzit pattern)

### Out of Scope

- AI speech analysis / phoneme feedback — complexity too high for MVP, can add later (but Whisper transcription IS in v1)
- YouTube integration / embedding — legal risk, against YouTube TOS
- Cloud sync / backup — local-only for v1
- Social features / sharing — personal tool first
- Video transcoding for exotic formats (avi, mkv, webm) — only mp4/mov for v1
- Standalone teleprompter app features — but text overlay/scroll IS in v1 as a view mode
- Multi-language support — English-focused for now

## Context

- **Inspiration:** [ShadowSpeak](https://www.shadowspeakapp.com) — web PWA for speech shadowing with curated speaker library and AI phoneme analysis. No native iOS app, no video self-recording comparison.
- **Competitive gap:** Existing shadowing apps (Speak Pro, TubeShad, Shadow) focus on audio-only comparison for language learning. No iOS app combines video playback + camera recording + visual comparison.
- **Target use:** Personal public speaking training with 2-10 minute video segments (TED talks, presentations, interviews).
- **Legal approach:** User-uploaded videos only. App never interacts with YouTube or any third-party video service. User imports from Camera Roll — same as any video editor app. TOS includes clause that users must own or have rights to imported content.
- **Technical foundation:** Swift/SwiftUI, AVFoundation (AVPlayer + AVCaptureSession simultaneously), AVAudioSession in .playAndRecord mode, SwiftData for persistence.
- **AI stack:** OpenAI Whisper for transcription (reuse sezit WhisperAPIClient + AudioPreprocessor patterns), on-device SFSpeechRecognizer fallback (reuse digzit pattern), Keychain for API key storage.
- **Prior art in workspace:** Developer has multiple iOS apps — sezit (Whisper + GPT transcription keyboard), digzit (SwiftData + Whisper + Vision), linkzit (Cloudflare backend). Significant patterns to reuse: KeychainHelper, AudioPreprocessor, WhisperAPIClient, SwiftData schema versioning, @Observable service pattern, state machine for recording.

## Constraints

- **Platform**: iOS only (iPhone), minimum iOS 16+
- **Video formats**: mp4/mov only (native AVPlayer support, no transcoding)
- **Storage**: All data local on-device, no server/cloud component
- **Privacy**: Camera + microphone access required, no data leaves device
- **App Store**: Must comply with Apple review guidelines — no copyrighted content distribution

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| User-uploaded content, not curated library | Avoids content licensing, infinite content, simpler to build | — Pending |
| Multi-content: video + audio + text | Expands use cases beyond video-only; text mode enables script practice | — Pending |
| DJ-fader overlay UI, not split-screen | Small phone screen makes split-screen impractical; fader is more intuitive | — Pending |
| mp4/mov only, no transcoding | Simplest path; iOS screen recordings and phone videos are already mp4/mov | — Pending |
| No YouTube integration | Legal risk, TOS violations, auth issues; user imports their own files | — Pending |
| OpenAI Whisper for transcription | Proven in sezit/digzit; high quality; with on-device fallback | — Pending |
| SwiftUI + AVFoundation + SwiftData | Native iOS stack, best camera/audio performance, proven persistence | — Pending |
| Reuse sezit/digzit patterns | KeychainHelper, AudioPreprocessor, WhisperAPIClient, @Observable services | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-25 after initialization*
