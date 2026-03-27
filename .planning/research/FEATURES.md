# Feature Research

**Domain:** Native iOS speech shadowing app with video self-recording and visual comparison
**Researched:** 2026-03-25
**Confidence:** MEDIUM — competitor feature sets verified via official sites and app stores; user expectations inferred from app reviews and category norms; no direct user interviews

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Import reference video from device | Users need their own content; no app can curate everything | LOW | PHPickerViewController for Camera Roll; mp4/mov only; system handles file access |
| Play reference video while simultaneously capturing user via front camera | Core act of shadowing requires hearing/seeing reference while performing | HIGH | AVFoundation: AVPlayer + AVCaptureSession sharing the same AVAudioSession in `.playAndRecord` mode; known iOS complexity |
| Audio routing: reference to headphones, mic captures user voice | Without this, the reference audio bleeds into the mic recording | MEDIUM | AVAudioSession with `.allowBluetooth` / output override; critical for AirPods users |
| Save recorded sessions (reference + user recording pair) | Users can't improve without revisiting past attempts | LOW | Local file storage; pair stored as a bundle (reference path + user recording path + timestamp) |
| Review saved sessions with the same playback UI | Reviewing past sessions is the entire training loop | MEDIUM | Reuse the fader playback controller; session list feeds the same player |
| Session history list with timestamps | Basic library UX; users need to navigate their practice history | LOW | Simple list view sorted by date; thumbnail from first frame of reference video is a nice touch |
| Basic playback controls (pause, scrub, speed) | Every video player app has these | MEDIUM | Speed adjustment (0.5x, 0.75x, 1x) is especially valued in shadowing workflows per TubeShad and Speak Pro reviews |
| Microphone and camera permission handling with clear explanations | iOS requires permissions; poor handling causes immediate 1-star reviews | LOW | Standard iOS permission flow; explain why each is needed before requesting |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| DJ-fader video blend: reference ↔ overlay ↔ self-only | No competitor offers this; lets user visually study their own body language, posture, and gesture relative to the model speaker — the core insight gap in all audio-only shadowing apps | HIGH | Metal or Core Image compositing; fader maps to alpha blend between two video layers; must run at 60fps without dropped frames to feel responsive |
| DJ-fader audio blend: reference audio ↔ user audio | Independent audio control from video blend; lets user isolate their voice against reference or hear the blend naturally | MEDIUM | AVAudioMixing or manual PCM mixing; separate from video fader; must be real-time during playback |
| Side-by-side visual delivery comparison | Actors, presenters, and coaches specifically want to see posture/gesture/facial expression against the model — not just hear audio | HIGH | Overlay mode and/or a split reveal slider variant; depends on the fader UI delivering an intuitive interaction model |
| User-supplied video as reference (not a curated library) | Unlimited content: users can shadow any speaker, any accent, any style — TED talks, interviews, film scenes, their own coach | LOW | PHPickerViewController; no server needed; users self-select what's relevant to their goal |
| Fully offline / no account required | Privacy-sensitive users (executives, actors, coaches) will trust the app more; no onboarding friction | LOW | Consequence of local-only design; must be a marketing claim, not just a technical fact |
| Segment looping for hard sections | Users identify a 10-second delivery moment they want to drill; TubeShad's most-praised feature per reviews | MEDIUM | Set loop in/out points on the timeline; loop plays automatically until user taps stop |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| YouTube / internet video import | Users want to shadow YouTube videos directly without downloading | Violates YouTube ToS, requires OAuth and Google approval, content may be removed mid-session, creates App Store rejection risk; ShadowSpeak and TubeShad use workarounds that are legally fragile | Import from Camera Roll; users can download videos using any tool they choose before importing — keeps legal liability entirely with the user |
| AI phoneme / pronunciation scoring | ShadowSpeak's flagship feature; users see "AI feedback" as a quality signal | Requires training data, ML model, server infrastructure, or licensed APIs; scope is a full separate product; errors in phoneme scoring generate user complaints that undermine trust | Defer to v2+; ship the visual comparison loop first; visual self-awareness is the actual gap |
| Cloud sync / iCloud backup | Users are used to apps syncing across devices | Adds server or CloudKit complexity; increases privacy surface; session files can be large (video); conflicts with "fully offline" pitch | Consider iCloud Drive export as a manual export option in v1.x, not auto-sync |
| Social sharing / "post your session" | Gamification; users may want to share progress | Requires encoding pipeline, watermarking, privacy review; videos contain user's face and voice — liability and moderation surface | Let users export to Camera Roll and share however they choose via iOS share sheet |
| Built-in content library / curated speakers | ShadowSpeak and Speak Pro offer this; users may expect it | Content licensing is complex; curated libraries need curation effort and legal review; limits flexibility; Mimzit's model (user-supplied) is actually a stronger proposition | Document in onboarding that users can import any video from their Camera Roll — TED talks, movie scenes, interviews |
| Real-time AI feedback during recording | "Correct me as I speak" is appealing | Inference during AVCaptureSession increases thermal load; on-device speech-to-text during front camera capture is untested territory for latency; degrades core UX if laggy | Post-session review loop is more effective for delivery training anyway; AI is a v2 consideration |
| Teleprompter / script display | SpeakVibe has this; actors want it | Different product category; adds complexity; competes for screen real estate with video comparison UI | Out of scope; the comparison loop is the product |
| Multi-device recording (iPad + iPhone) | Pro coaches may want a wider angle | AVFoundation does not support cross-device capture; requires Multipeer Connectivity or server roundtrip; massive complexity | Single iPhone is the constraint; good framing instructions in onboarding serve this need |

---

## Feature Dependencies

```
[Import Reference Video]
    └──requires──> [Camera Roll Permission + PHPickerViewController]
    └──enables──> [Record Session]

[Record Session]
    └──requires──> [Import Reference Video]
    └──requires──> [AVAudioSession .playAndRecord]
    └──requires──> [Camera Permission (front camera)]
    └──requires──> [Microphone Permission]
    └──requires──> [Audio Routing to Headphones]
    └──enables──> [Save Session]
    └──enables──> [Session History]

[Audio Routing to Headphones]
    └──requires──> [AVAudioSession configuration before capture starts]
    └──must resolve──> [Reference audio leaking into mic recording - critical bug risk]

[Save Session]
    └──requires──> [Record Session]
    └──stores──> [reference video path + user recording file + timestamp metadata]
    └──enables──> [Review Session]

[Review Session]
    └──requires──> [Save Session]
    └──requires──> [DJ-Fader Video Blend]
    └──requires──> [DJ-Fader Audio Blend]

[DJ-Fader Video Blend]
    └──requires──> [AVPlayer (reference) + AVSampleBufferDisplayLayer or MTKView (user recording)]
    └──enhances──> [Review Session]
    └──is also used in──> [Live Record Session preview]

[DJ-Fader Audio Blend]
    └──requires──> [Independent audio mix of two tracks during playback]
    └──enhances──> [Review Session]

[Segment Looping]
    └──requires──> [Review Session playback]
    └──enhances──> [Review Session]

[Session History]
    └──requires──> [Save Session]
    └──enables──> [Review Session]

[Playback Speed Control]
    └──requires──> [AVPlayer rate property]
    └──enhances──> [Record Session (reference playback speed)]
    └──enhances──> [Review Session]
```

### Dependency Notes

- **Record Session requires Audio Routing:** If AVAudioSession routing is wrong, reference audio bleeds into the mic track and every recorded session is corrupted. This must be solved before any session recording is considered done.
- **DJ-Fader Video Blend drives core value:** Everything else is scaffolding. The fader is the product. It must feel 60fps smooth or the differentiator fails.
- **Review Session reuses Record Session's player:** The fader playback UI is not a separate feature — it's the same compositing layer used during live recording, replaying stored files instead of live feeds. Design the compositing layer once, parameterize the source.
- **Segment Looping enhances but does not block:** Can ship v1 without it; add in v1.1 once core loop is validated.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] Import reference video from Camera Roll (PHPickerViewController, mp4/mov) — users have no content without this
- [ ] Play reference video + simultaneously record user via front camera — the core act
- [ ] Audio routing: reference to headphones, mic captures voice — without this, recordings are unusable
- [ ] DJ-fader video blend (reference ↔ overlay ↔ self-only) — the entire differentiator; if this doesn't work well, nothing else matters
- [ ] DJ-fader audio blend (reference ↔ user audio) — completes the comparison loop
- [ ] Save session (reference path + user recording + timestamp) — enables the review loop
- [ ] Session history list — navigate past practice sessions
- [ ] Review past sessions with the same fader UI — closes the training loop

### Add After Validation (v1.x)

Features to add once core recording and playback loop is proven.

- [ ] Segment looping (set in/out points for drilling) — add when users report wanting to repeat specific sections; TubeShad proves this is the most-used advanced feature
- [ ] Playback speed control during recording session (0.5x / 0.75x / 1x) — add when users report reference video is too fast to shadow; common complaint across all shadowing apps
- [ ] Session rename / notes — add when session history grows past a handful; users need to label sessions by content
- [ ] Export session to Camera Roll — add when users ask to share or back up recordings; iOS share sheet handles distribution

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] AI phoneme / pronunciation analysis — defer; requires ML infrastructure; risk of poor analysis generating user complaints
- [ ] iCloud Drive manual export / backup — defer; complexity spike; not blocking core value
- [ ] Waveform visualization during playback — defer; nice for audio comparison but adds rendering complexity; validate demand first
- [ ] Apple Watch complication / remote control — defer; low priority, niche use case

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Import reference video | HIGH | LOW | P1 |
| Simultaneous record + play | HIGH | HIGH | P1 |
| Audio routing to headphones | HIGH | MEDIUM | P1 |
| DJ-fader video blend | HIGH | HIGH | P1 |
| DJ-fader audio blend | HIGH | MEDIUM | P1 |
| Save session | HIGH | LOW | P1 |
| Session history | HIGH | LOW | P1 |
| Review session with fader UI | HIGH | MEDIUM | P1 |
| Playback speed control | MEDIUM | LOW | P2 |
| Segment looping | MEDIUM | MEDIUM | P2 |
| Session rename / notes | MEDIUM | LOW | P2 |
| Export to Camera Roll | MEDIUM | LOW | P2 |
| Waveform visualization | LOW | MEDIUM | P3 |
| AI speech analysis | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | ShadowSpeak (web PWA) | Speak Pro (iOS) | TubeShad (iOS) | Orai (iOS) | Speeko (iOS) | SpeakVibe (iOS) | Mimzit (planned) |
|---------|----------------------|-----------------|----------------|------------|--------------|-----------------|-------------------|
| Content source | Curated speaker library | YouTube videos via app | YouTube search | User's own speech (no reference) | Structured lessons | User's own speech | User-imported from Camera Roll |
| Record yourself | Yes (audio) | Yes (audio) | Yes (audio) | Yes (audio) | Yes (audio) | Yes (video) | Yes (video — front camera) |
| Video self-recording | No | No | No | No | No | Yes (no reference video overlay) | Yes — unique: simultaneous with reference video |
| Visual comparison with reference | No | No | No | No | No | No (solo recording only) | Yes — DJ-fader blend; no competitor does this |
| Audio comparison with reference | Yes | Yes | Yes | No (solo) | No (solo) | No (solo) | Yes — independent fader |
| AI phoneme / speech analysis | Yes (flagship) | Yes | Yes | Yes | Yes | Yes | No (v1); planned v2+ |
| Progress tracking | Yes | Yes | Yes | Yes | Yes | Yes | Deferred; session history only in v1 |
| Playback speed control | Unknown | Yes | Yes | No | No | No | v1.x |
| Segment looping | Unknown | Unknown | Yes (praised) | No | No | No | v1.x |
| Offline / no account | No (web, login) | No (account) | No (account) | No (account) | No (account) | No (account) | Yes — fully local, no account |
| Platform | Web PWA | iOS | iOS/Android | iOS/Android | iOS/Android | iOS | iOS native |

### Competitive Gap Summary

No iOS app combines: (1) user-supplied video as reference, (2) simultaneous front-camera recording, and (3) visual blend comparison. SpeakVibe is the closest in recording video of the user, but it records solo with no reference video — the comparison loop does not exist. All audio-only shadowing apps (Speak Pro, TubeShad) miss the body language and visual delivery dimension entirely.

---

## Sources

- [ShadowSpeak](https://www.shadowspeakapp.com) — web PWA for public speaking shadowing with curated library and AI phoneme analysis (MEDIUM confidence — marketing page, features may vary in practice)
- [Speak Pro](https://speakpro.app/) — iOS shadowing app with YouTube content, record and compare audio (HIGH confidence — official site fetched)
- [TubeShad on App Store](https://apps.apple.com/us/app/tubeshad-english-shadowing/id6741210342) — iOS/Android shadowing via YouTube, spaced repetition (MEDIUM confidence — App Store listing + Product Hunt)
- [Orai on App Store](https://apps.apple.com/us/app/orai-improve-public-speaking/id1203178170) — AI public speaking coach, solo recordings, filler word / pace analysis (HIGH confidence — App Store + official site)
- [Speeko on App Store](https://apps.apple.com/us/app/speeko-ai-for-public-speaking/id1071468459) — AI speech coach, guided lessons, real-time pace/tone feedback (HIGH confidence — App Store + official site)
- [SpeakVibe on App Store](https://apps.apple.com/us/app/speakvibe-public-speaking-ai/id6738028828) — AI speech coach with video recording, body language feedback, teleprompter (HIGH confidence — App Store)
- [Orai vs Speeko comparison — Yoodli blog](https://yoodli.ai/blog/orai-vs-speeko-what-to-know) — third-party feature comparison (MEDIUM confidence)
- [Apple AVFoundation Multi-Camera documentation](https://developer.apple.com/documentation/avfoundation/capture_setup/avmulticampip_capturing_from_multiple_cameras) — simultaneous camera capture capability (HIGH confidence — official Apple docs)

---

*Feature research for: Native iOS speech shadowing app with video comparison (Mimzit)*
*Researched: 2026-03-25*
