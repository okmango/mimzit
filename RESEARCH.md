# Mimzit — Research Document

> **Date:** 2026-03-25
> **Status:** Initial Research / Feasibility

## 1. App Concept

A mobile iOS app for **speech shadowing and public speaking training**. The user:

1. Imports/uploads a reference video (e.g., a TED Talk speaker, actor monologue, interview)
2. Plays the video while simultaneously recording themselves via the front camera
3. Reviews both recordings side-by-side (or layered with a DJ-fader-style UI)
4. Saves sessions to track progress over time (first attempt vs. latest attempt)

**Key differentiator idea:** DJ-fader UI for small screens — one fader controls video blend (left = reference only, center = overlay, right = self only), optionally a second fader for audio blend. AirPods would be ideal for hearing the reference speaker while recording.

---

## 2. Competitor Analysis

### 2.1 Direct Competitors (Speech Shadowing with Video + Self-Recording)

| App | Platform | What It Does | Gap vs. Our Concept |
|-----|----------|-------------|---------------------|
| **[Speak Pro](https://speakpro.app/)** (iOS) | iOS | Turns YouTube videos into shadowing practice. Record your voice alongside the video, compare in sync. | Focuses on **audio** comparison, not video side-by-side. No self-video recording overlay. Language learning focused. |
| **[TubeShad](https://apps.apple.com/us/app/tubeshad-english-shadowing/id6741210342)** (iOS) | iOS | YouTube-based shadowing. Slow down, repeat sections, record yourself. | Audio-focused shadowing. No camera recording of the user. Language learning oriented. |
| **[Shadow: Speak & Learn](https://apps.apple.com/us/app/shadow-speak-learn-language/id6758269114)** (iOS) | iOS | AI pronunciation feedback, karaoke-style word matching. | AI feedback on audio only, no video comparison. |
| **[Shadowing Player](https://apps.apple.com/us/app/shadowing-player-languages/id6514319878)** (iOS) | iOS | Audio/video/YouTube player for shadowing practice. | Player only — no self-recording feature. |
| **[Parroto](https://parroto.app/shadowing)** (iOS) | iOS | AI speech analysis, real-time pronunciation feedback. | Audio-only analysis. No video recording/comparison. |
| **[SHADOWENG](https://play.google.com/store/apps/details?id=www.shadoweng.com)** | Android | Import videos with subtitles for shadowing. | Android only. No video self-recording. |

### 2.2 Adjacent Competitors (Public Speaking / Actor Training)

| App | Platform | What It Does | Gap vs. Our Concept |
|-----|----------|-------------|---------------------|
| **[Orai](https://apps.apple.com/us/app/orai-improve-public-speaking/id1203178170)** | iOS | AI speech coach — record yourself, get feedback on clarity, pacing, filler words. | No reference video comparison. Analyzes your speech in isolation. |
| **[Speeko](https://apps.apple.com/us/app/speeko-ai-for-public-speaking/id1071468459)** | iOS | Real-time voice coaching — pitch, energy, pace, filler words. | No reference video. Voice-only analysis. |
| **[SpeakVibe](https://apps.apple.com/us/app/speakvibe-public-speaking-ai/id6738028828)** | iOS | Record yourself, get AI feedback on voice + body language + delivery. | Has video recording but no reference video comparison. |
| **[Yoodli](https://www.yoodli.ai/)** | Web | AI speech analytics — filler words, pacing, body language via webcam. | Web only. No side-by-side with a reference speaker. |
| **[coldRead](https://www.coldreadapp.com/)** | iOS | Actor rehearsal — record lines, app acts as scene reader. | Script-based, not video mimic. |
| **[Rehearsal Pro](https://rehearsal.pro/)** | iOS | Actor line memorization and rehearsal. | Script/audio based. No video comparison. |
| **[VirtualSpeech](https://virtualspeech.com/)** | Web/VR | VR presentation practice with virtual audience. | VR-focused, no real speaker mimic. |

### 2.3 Competitive Gap Summary

**No existing iOS app combines all three:**
1. Playing a reference speaker video
2. Simultaneously recording the user's video + audio
3. Side-by-side or overlay playback for visual comparison

The closest are **Speak Pro** and **TubeShad**, which do audio shadowing from YouTube but lack the **video self-recording** comparison. **SpeakVibe** records your video but doesn't compare against a reference. This is a genuine gap in the market.

**The niche is especially open for:**
- Public speaking body language training (gestures, posture, facial expressions)
- Actor/theater training (emotional expression, physicality)
- Presentation coaching (comparing delivery styles)

---

## 3. The Original Website App — ShadowSpeak

**URL:** https://www.shadowspeakapp.com (also deployed at shadowspeakapp.vercel.app)

### What ShadowSpeak Does
- Speech shadowing platform for public speaking training
- You listen to a speaker and repeat what they say in real-time, mimicking rhythm, tone, and body language
- **AI Speech Analysis** — evaluates individual phonemes (R, TH, L, etc.) against native speakers with color-coded feedback (green = accurate, red = needs work)
- **Speaker Library** — curated library of "world-class speakers" (likely TED Talk style content)
- Recordings saved locally

### Platform & Pricing
- **Web-only** — built as a Progressive Web App (PWA) on Vercel
- Installable on iOS/Android as a PWA (not a native App Store app)
- **Free plan:** 10 min/day, basic speaker library
- **Pro plan:** Unlimited (price not disclosed)
- Claims 4.9/5 from 1,250 reviews

### Key Observations
- **No native iOS/Android app** — this is the gap we'd fill
- **Uses a curated speaker library** — they likely license or host their own content, not user-uploaded
- **PWA limitations on iOS:** No background audio, limited camera access, no picture-in-picture, restricted offline capabilities — a native app would be significantly better
- **AI phoneme analysis** is a nice feature but adds complexity — we can differentiate with the **visual comparison** (video overlay/side-by-side) which ShadowSpeak doesn't emphasize
- **No DJ-fader-style UI** — their approach appears more traditional split-screen

### Our Differentiation vs. ShadowSpeak
| Feature | ShadowSpeak | Mimzit (Ours) |
|---------|-------------|-----------------|
| Platform | PWA (web) | Native iOS |
| Video source | Curated speaker library | User-uploaded (any video) |
| Visual comparison | Basic split-screen | DJ-fader overlay (video + audio blend) |
| AI analysis | Phoneme-level audio analysis | Not in MVP (future feature) |
| Offline support | Limited (PWA) | Full (native) |
| Camera quality | WebRTC (limited) | AVCaptureSession (full iOS camera pipeline) |
| Session history | Basic | Full timeline with progress tracking |
| AirPods support | Basic web audio | Native audio routing, .playAndRecord |

---

## 4. Legal Analysis — Video Content

### 4.1 How Users Get Reference Videos

**Approach: User-uploaded content (recommended)**

The app does NOT download, stream, or embed YouTube/third-party videos directly. Instead:
- The user records/saves a video on their device by whatever means they choose
- The user imports that video file into the app from their Camera Roll / Files
- The app treats it as an opaque video file — it has no knowledge of the source

**Why this is the safest approach:**

| Concern | Risk Level | Reasoning |
|---------|-----------|-----------|
| **YouTube TOS violation** | **Low (for us)** | YouTube's TOS binds the *user*, not our app. Our app never interacts with YouTube. The user decides how they obtained the video. Similar to how any video editor app works. |
| **Copyright infringement** | **Low (for us)** | Under DMCA safe harbor / EU intermediary liability principles, platforms that host user-uploaded content have liability shields if they have proper DMCA takedown procedures. But we don't even host the content — it stays 100% local on the user's device. |
| **App Store rejection** | **Low** | Apple allows apps that import user videos (every video editor does this). No special authorization needed since we're not streaming third-party content. We're not providing access to copyrighted material — the user brings their own. |
| **Screen recording legality** | **Not our concern** | Screen recording for personal use is generally legal in most jurisdictions. The user makes their own choice about what they import. |

### 4.2 What NOT to Do

- **Do NOT embed a YouTube player / WebView** — YouTube's API TOS prohibits overlaying, modifying, or obscuring their player. Also causes auth/ad issues as the user mentioned.
- **Do NOT auto-download from YouTube URLs** — This is explicitly against YouTube TOS and could get the app rejected.
- **Do NOT provide a built-in browser to navigate to YouTube** — Gray area, but risky.

### 4.3 Recommended Legal Safeguards

1. **Terms of Service:** Include a clause that users must only import content they have the right to use, or content used under fair use for personal educational purposes.
2. **No cloud upload:** Keep all videos local on-device. Never upload reference videos to any server.
3. **No sharing feature for reference videos:** Users can share their own recordings but not the imported reference videos.
4. **Privacy Policy:** Standard camera/microphone access disclosures.

### 4.4 Fair Use Argument (for the user's benefit)

The user's personal use likely qualifies as fair use because:
- **Purpose:** Educational/personal skill development (transformative use)
- **No commercial redistribution:** Videos stay on their phone
- **No market harm:** Doesn't replace the original video's market

---

## 5. Technical Considerations — Video Formats

### 5.1 iOS AVPlayer Supported Formats

| Format | Container | Status |
|--------|-----------|--------|
| H.264 / AVC | .mp4, .mov, .m4v | Fully supported |
| H.265 / HEVC | .mp4, .mov | Supported (iOS 11+) |
| AAC audio | .m4a, .mp4 | Fully supported |
| ProRes | .mov | Supported (newer devices) |

### 5.2 Problematic Formats Users Might Import

| Format | Issue | Solution |
|--------|-------|----------|
| .avi (various codecs) | Not supported by AVPlayer | Needs transcoding |
| .mkv (Matroska) | Not supported | Needs transcoding |
| .webm (VP8/VP9) | Not natively supported | Needs transcoding |
| .flv | Not supported | Needs transcoding |
| .wmv | Not supported | Needs transcoding |

### 5.3 Transcoding Strategy

**Option A: On-device transcoding with AVAssetExportSession**
- Convert unsupported formats to H.264 .mp4 on import
- Pros: No external dependencies, Apple-native
- Cons: Can only convert formats AVFoundation can *read* (limited)

**Option B: FFmpeg (via mobile-ffmpeg / ffmpeg-kit)**
- Handles virtually any input format
- Pros: Universal format support
- Cons: Adds ~15-30MB to app size, GPL licensing considerations (use LGPL build)

**Option C: Reject unsupported formats**
- Only accept .mp4, .mov, .m4v
- Pros: Simplest, no transcoding needed
- Cons: Users with .avi/.mkv files can't use them directly

**Recommendation:** Start with **Option C** (accept only iOS-native formats). Most screen recordings and phone videos are already .mp4/.mov. If user demand for other formats arises, add FFmpeg-kit later.

### 5.4 Simultaneous Playback + Recording

This is the core technical challenge:
- **AVCaptureSession** for camera recording
- **AVPlayer** for reference video playback
- Both need to run simultaneously — this is supported on iOS but requires careful audio session management
- **AVAudioSession** category should be `.playAndRecord` with `.defaultToSpeaker` or route to headphones
- AirPods routing: reference audio to AirPods, mic captures user's voice — this works naturally with `.playAndRecord`

---

## 6. Key Risks & Open Questions

| # | Question | Priority |
|---|----------|----------|
| 1 | Which website did the user originally see? Need URL to analyze their exact feature set. | Medium |
| 2 | Simultaneous AVPlayer + AVCaptureSession performance on older iPhones? | High — needs prototype |
| 3 | Audio bleed — if user uses speakers instead of headphones, reference audio bleeds into recording. | Medium — mitigate with headphone detection + warning |
| 4 | Storage — dual video files per session could be large. Need cleanup/compression strategy. | Medium |
| 5 | Minimum iOS version target? (iOS 16+ recommended for modern AVFoundation APIs) | Low |

---

## 7. Conclusion & Recommendation

**The niche is real and underserved.** Existing shadowing apps focus on audio-only comparison for language learning. No iOS app combines video playback + camera recording + visual comparison for public speaking / acting training.

**Recommended MVP scope:**
1. Import video from Camera Roll (mp4/mov only)
2. Play reference video + record user simultaneously
3. DJ-fader playback UI (video blend slider + audio blend slider)
4. Save sessions with timestamps
5. Session history — review past recordings

**Not in MVP:**
- AI feedback / analysis
- YouTube integration
- Cloud sync
- Social/sharing features
- Transcoding for exotic formats
