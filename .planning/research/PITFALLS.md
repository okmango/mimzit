# Pitfalls Research

**Domain:** Native iOS app — simultaneous AVPlayer video playback + AVCaptureSession camera recording with audio fader UI
**Researched:** 2026-03-25
**Confidence:** HIGH (most pitfalls verified through Apple Developer Forums, official Apple docs, and developer post-mortems)

---

## Critical Pitfalls

### Pitfall 1: AVCaptureSession Auto-Configures the Audio Session and Kills Reference Audio

**What goes wrong:**
By default, `AVCaptureSession.automaticallyConfiguresApplicationAudioSession` is `true`. The moment you add a microphone input to the capture session, it silently reconfigures the shared `AVAudioSession` — switching the category and clearing any options you set. This pauses or cuts the audio from `AVPlayer` playing the reference video. Users experience the reference video going silent the moment recording begins.

**Why it happens:**
Developers set up `AVAudioSession` manually (`.playAndRecord`, `.mixWithOthers`) then add capture inputs — but adding inputs triggers the auto-configuration override, undoing their work. The override happens silently with no log output or error.

**How to avoid:**
Set `captureSession.automaticallyConfiguresApplicationAudioSession = false` before adding any inputs. Then configure `AVAudioSession` manually:
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
try session.setActive(true)
captureSession.automaticallyConfiguresApplicationAudioSession = false
// Now add inputs
```
Order matters: set the flag before configuring inputs.

**Warning signs:**
- Reference video plays silently the moment recording starts
- Audio works fine in isolation (player-only or recorder-only) but breaks when both run
- `AVAudioSession.currentRoute` changes unexpectedly after `captureSession.startRunning()`

**Phase to address:** Phase 1 (Core Recording Engine) — this must be solved before any UI work. Get a test harness running both systems simultaneously with audio audible from AVPlayer before any other feature work.

---

### Pitfall 2: Reference Audio Bleeds Into the User's Recorded Track

**What goes wrong:**
When AirPods or wired headphones are not being used, the reference video plays through the iPhone speaker. The front-facing microphone picks up this speaker audio. The user's self-recording contains an echo of the reference speaker. This makes audio comparison meaningless — you can't hear the user's actual voice clearly.

**Why it happens:**
The app uses the default audio route (speaker output + built-in mic). Physical acoustic bleed is unavoidable in this configuration. Developers test with headphones and never discover this.

**How to avoid:**
- Document clearly in UI that headphones are required for accurate audio capture. Show an onboarding warning if no headphones are connected (`AVAudioSession.sharedInstance().currentRoute.outputs` check).
- When headphones are detected: reference audio routes to headphones, mic captures only the user's voice.
- When no headphones: either block recording with a prompt ("Connect headphones for best results") or warn prominently.
- Check `AVAudioSession` output route before allowing recording to start.

**Warning signs:**
- Self-recorded audio in simulator/device testing sounds "roomy" or has an echo
- Any testing without headphones produces bleed immediately
- Reviewer feedback about "echo" on the recording

**Phase to address:** Phase 1 (Core Recording Engine) — route detection must be part of the initial audio session setup, not added later as a "nice to have."

---

### Pitfall 3: Recording Silently Destroyed by Background Transition

**What goes wrong:**
When the user receives a phone call, presses the home button, gets a Siri activation, or triggers any interruption, `AVCaptureSession` stops. `AVCaptureMovieFileOutput` recordings in progress at that moment are stopped and the partial file may be corrupt or unreadable. If the app doesn't handle `AVCaptureSessionWasInterruptedNotification`, the UI shows "recording" while nothing is actually being captured.

**Why it happens:**
iOS camera is hardware-exclusive and cannot run in the background. The system sends `interruptionReason: .videoDeviceNotAvailableInBackground` but if you don't listen for it, you never know. AVCaptureMovieFileOutput does not support pause/resume.

**How to avoid:**
- Subscribe to `AVCaptureSessionWasInterruptedNotification` and `AVCaptureSessionInterruptionEndedNotification`.
- On interruption: stop recording, save any in-progress file, update UI to reflect stopped state, alert the user their session ended early.
- On interruption end: do NOT auto-resume recording. Show UI asking user to start a new session.
- Consider `AVAssetWriter` instead of `AVCaptureMovieFileOutput` for more interruption control (but see Pitfall 7 for tradeoffs).

**Warning signs:**
- Recording indicator stays red after a phone call
- File exists on disk but is 0 bytes or fails to open with `AVAsset`
- User complains practice sessions disappear randomly

**Phase to address:** Phase 1 (Core Recording Engine) — interruption handling is not optional. Build and test with a real phone call before shipping phase 1.

---

### Pitfall 4: `AVCaptureMovieFileOutput` recordedDuration Is Inaccurate — Don't Trust It for Sync

**What goes wrong:**
When using `AVCaptureMovieFileOutput`, the `recordedDuration` property is unreliable — it can differ from the actual file duration by hundreds of milliseconds. Using this value to align the recorded clip with the reference video during playback review produces persistent A/V sync drift that appears random and cannot be tuned away.

**Why it happens:**
`recordedDuration` represents the duration of data written, not the actual CMTime range of the recorded asset. Network (NTP) clock adjustments, hardware startup latency, and encoding pipeline delays all introduce offset that `recordedDuration` doesn't account for. This was documented specifically in 2025 by developers building recording review features.

**How to avoid:**
- Record the `CACurrentMediaTime()` or `CMClock.hostTimeClock` timestamp at the moment recording starts AND at the moment `AVPlayer` begins playing the reference.
- Use the delta between these two timestamps as your sync offset when building the review playback UI.
- Use `AVAsset.duration` from the written file (not `recordedDuration`) for display.
- For the review fader, seek both players to positions calculated from this captured offset, not from reported durations.

**Warning signs:**
- Review playback feels "off" even when recording started simultaneously with reference play
- Sync is inconsistent across devices or recording lengths
- Drift appears to grow over longer sessions

**Phase to address:** Phase 2 (Session Review / Fader Playback) — the sync offset must be captured in Phase 1 and consumed in Phase 2. Design the data model to carry this offset from day one.

---

### Pitfall 5: AVAudioSession Interruption Not Resumed After Phone Call

**What goes wrong:**
After a phone call ends, `AVAudioSession` may not automatically return to `.playAndRecord`. The `AVCaptureSession` might resume running (camera preview returns) but audio input/output is silent or routed incorrectly because the audio session wasn't reactivated. The user returns from the call, sees the camera preview, presses record, and gets a video with no sound.

**Why it happens:**
iOS sends `AVAudioSessionInterruptionNotification` with `.ended` type, but the system does NOT guarantee audio session reactivation. If `AVAudioSessionInterruptionOptionShouldResume` is not set in the notification's `userInfo`, the app must manually call `setActive(true)` again. Many developers only handle the `.began` case.

**How to avoid:**
- Handle both `.began` and `.ended` in your `AVAudioSessionInterruptionNotification` observer.
- On `.ended`: check `shouldResume` flag. If true (or absent, be defensive), call `AVAudioSession.sharedInstance().setActive(true)` and re-verify category/options are still `.playAndRecord` with `.mixWithOthers`.
- After reactivation, test that `AVPlayer` audio is audible and `AVCaptureSession` audio input is live.

**Warning signs:**
- Silent recording after returning from a call
- Works correctly on first launch but fails after any interruption
- `AVAudioSession.currentRoute` shows the expected route but audio is still silent

**Phase to address:** Phase 1 (Core Recording Engine) — test explicitly with phone call simulation using the iOS Simulator's "Simulate Memory Warning" and on-device testing.

---

### Pitfall 6: Memory Pressure from Two Simultaneous Video Pipelines Causes OS Termination

**What goes wrong:**
Running `AVPlayer` (decoding reference video) + `AVCaptureSession` (encoding from camera) simultaneously keeps the GPU and CPU in a sustained high-load state. On older supported hardware (iPhone 8, iOS 16 minimum), combined pipeline memory for two video streams can push the app into memory warning territory. The OS silently terminates the app mid-session with no crash log the user sees.

**Why it happens:**
Each video pipeline holds frame buffers in memory. AVPlayer decodes frames ahead (read-ahead buffer). AVCaptureSession buffers incoming frames for encoding. The fader UI compositing these two streams adds a third GPU pass. On constrained devices, this stack exhausts available memory.

**How to avoid:**
- Set appropriate `AVPlayer.currentItem.preferredMaximumResolution` — cap reference video decoding to screen resolution (never decode 4K for a phone screen).
- Set `AVCaptureSession.sessionPreset` to `.high` or `.medium` (not `.hd4K3840x2160`) for the user's recording — front camera at 1080p30 is sufficient.
- Subscribe to `UIApplication.didReceiveMemoryWarningNotification`. On warning: reduce capture preset, log the event, alert the user.
- Use Instruments (Allocations + GPU Driver) during development to profile the combined workload.

**Warning signs:**
- App disappears without crash on older devices (memory termination)
- Instruments shows `VMTracker` dirty memory growing during a session
- Device gets warm quickly during recording (thermal pressure preceding memory pressure)

**Phase to address:** Phase 1 (Core Recording Engine) — set conservative defaults immediately. Phase 3 (Performance / Polish) — profile on oldest supported device.

---

### Pitfall 7: AVAssetWriter Audio-Video Sync Breaks When Video Stabilization Is Enabled

**What goes wrong:**
If you choose `AVAssetWriter` over `AVCaptureMovieFileOutput` for more control and later enable video stabilization, video frames begin arriving approximately 0.6 seconds late relative to audio frames. The result is a recording where the user's lips are visibly out of sync with their voice — a show-stopping UX failure.

**Why it happens:**
Video stabilization requires a frame buffer to compute the stabilization transform — frames are held before being delivered to `AVCaptureVideoDataOutput`. Audio frames have no equivalent delay, so they arrive 0.6s ahead of the corresponding video. `AVCaptureMovieFileOutput` handles this internally; `AVAssetWriter` does not.

**How to avoid:**
Use `AVCaptureMovieFileOutput` for the initial implementation. It handles stabilization-induced delay correctly, requires less setup code, and produces reliable audio-video sync. Only switch to `AVAssetWriter` if you have a specific requirement (real-time frame processing, custom overlays during encoding) that cannot be achieved otherwise.

If you must use `AVAssetWriter`, disable `AVCaptureConnection.preferredVideoStabilizationMode` entirely.

**Warning signs:**
- Lips out of sync with audio in self-recording
- Sync is consistent across a recording (fixed offset, not drift) — indicates pipeline delay, not clock drift
- Issue appears only when video stabilization is active

**Phase to address:** Phase 1 (Core Recording Engine) — choose recording API before writing any other code. This is a foundational architectural decision.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use `AVCaptureMovieFileOutput` without interruption handling | Less code, faster to build | Silent data loss on phone calls; corrupted sessions users can't replay | Never — handle interruptions in Phase 1 |
| Skip headphone route detection, always allow recording | Simpler permission flow | Reference audio bleeds into self-recording; core value proposition broken | Never for the primary use case |
| Trust `recordedDuration` for sync offset | Avoids timestamp math | Permanent A/V drift in review playback; users can't compare accurately | Never — capture sync timestamps explicitly |
| Omit `preferredMaximumResolution` on AVPlayer | Reference video plays at native resolution | Memory pressure on older devices; OS termination mid-session | Never — always cap to display resolution |
| Keep `automaticallyConfiguresApplicationAudioSession` as `true` | Less AVAudioSession boilerplate | Reference audio cut when recording starts; core feature broken | Never |
| Use `captureSession.sessionPreset = .hd4K3840x2160` | "Best quality" front camera | Thermal throttling within minutes on most devices | Never — `.high` (1080p30) is correct for front camera |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| AVAudioSession + AVCaptureSession | Configure audio session after adding inputs — gets overwritten | Set `automaticallyConfiguresApplicationAudioSession = false`, configure session first, then add inputs |
| AVPlayer + .playAndRecord | Forget `.mixWithOthers` option — player audio pauses when session activates | Always include `.mixWithOthers` (and `.allowBluetoothA2DP` for AirPods) in category options |
| AirPods audio routing | Assume default routing sends reference to ears and mic picks up voice | Verify with `currentRoute.outputs` before recording; AirPods mic is a shared resource that may not be selected |
| PHPhotoLibrary import | Request `.readWrite` authorization — triggers privacy prompt on first launch before user understands why | Use `.addOnly` when only saving, request at the moment the user initiates import with explanation |
| AVCaptureSession + Siri | No handling for Siri activation mid-session | Subscribe to `AVCaptureSessionWasInterruptedNotification`; treat Siri as interruption type |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Both video pipelines at full resolution | Device warm in 2 minutes, frame drops, eventual termination | Cap AVPlayer to display resolution via `preferredMaximumResolution`; use `.high` preset for capture | Immediately on iPhone SE 2 / iPhone 8 class hardware |
| Running capture session queue on main thread | UI freeze during preview, dropped preview frames | Always run session setup and `startRunning` on a dedicated serial `DispatchQueue` | From the first frame on any device |
| Decoding reference video without enabling hardware decode | CPU-heavy decode, thermal pressure | `AVPlayer` uses hardware decode by default; do not intercept frames via `AVPlayerItemVideoOutput` unless necessary | Any sustained playback session |
| Large MOV files in app's Documents directory without cleanup | App storage grows unbounded; users get "iPhone Storage Full" notifications | Track session file sizes, offer in-app deletion in session history, show storage used per session | After ~10-20 sessions of 2-5 minute videos |
| Keeping AVCaptureSession running during review playback | Unnecessary GPU/CPU/battery load after recording is complete | `stopRunning()` the capture session when the user moves to review mode | Always — wastes resources from day one |

---

## "Looks Done But Isn't" Checklist

- [ ] **Simultaneous playback + recording:** Verify reference audio is audible through headphones while recording is happening — not just that both objects are initialized
- [ ] **Interruption recovery:** Test by making a real phone call mid-recording on device. Verify: (1) recording stops cleanly, (2) partial file is saved and openable, (3) UI reflects stopped state, (4) audio session restores after call ends
- [ ] **Headphone routing:** Test with no headphones plugged in — verify app shows a warning rather than letting acoustic bleed happen silently
- [ ] **Review sync:** Record yourself clapping at frame 0 of the reference video. In review, step through frames — the clap should align visually and aurally between both tracks
- [ ] **Storage accounting:** Record 5 sessions of 3 minutes each. Check that all 5 session files are accessible, correctly named, and that deleting one session actually frees disk space
- [ ] **Background termination:** Lock the screen mid-recording. Verify the in-progress file is not corrupted and the app reopens cleanly to session history
- [ ] **Memory on older device:** Run a full 5-minute session on the oldest supported device (iPhone with iOS 16). Verify no memory termination via Instruments

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Auto audio session override not caught until late | MEDIUM | Add `automaticallyConfiguresApplicationAudioSession = false` and re-order initialization; regression-test all audio paths |
| Sync offset not captured at recording start | HIGH | Requires rethinking data model and possibly re-testing sync strategy; cannot be patched without re-architecting Phase 2 review playback |
| Interruption handling missing | MEDIUM | Add notification observers; harder to retrofit if session/recording state machine is already complex |
| No headphone route check | LOW | Add a route check + UI warning before recording begins; doesn't touch audio pipeline |
| Storage bloat discovered after launch | MEDIUM | Add session size display and delete flow; low risk but requires UI work and file management logic |
| Memory pressure on older devices | HIGH | Requires cap changes to both pipelines and possibly dropping minimum iOS version or device support |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Auto audio session override kills reference audio | Phase 1: Core Recording Engine | Both player audio and capture run simultaneously with audio audible — verified on device with headphones |
| Reference audio bleed into mic | Phase 1: Core Recording Engine | Test without headphones — warning UI appears; test with headphones — no bleed in recording |
| Background/interruption destroys recording | Phase 1: Core Recording Engine | Make a phone call mid-recording on device; confirm clean save and state reset |
| AVAudioSession not resumed after interruption | Phase 1: Core Recording Engine | Return from phone call; confirm reference audio plays and recording starts correctly |
| AVCaptureMovieFileOutput recordedDuration drift | Phase 1 (capture sync timestamp) + Phase 2 (review sync) | Clap sync test shows both streams aligned within 1 frame in review playback |
| Memory pressure from two pipelines | Phase 1: set caps; Phase 3: profile | Run Instruments on oldest supported device; no memory warning during 5-min session |
| AVAssetWriter + stabilization sync break | Phase 1: API selection decision | Use AVCaptureMovieFileOutput — this pitfall is avoided by not using AVAssetWriter |
| Storage bloat | Phase 2 (session history) | 10 sessions visible, each shows file size; deleting session frees disk space |
| App Store — missing privacy manifest | Pre-submission (final phase) | Privacy manifest declares camera + microphone; NSCameraUsageDescription and NSMicrophoneUsageDescription present and specific |
| App Store — insufficient permission purpose strings | Pre-submission | Purpose strings explain specific use: "to record you practicing alongside the reference video" — not generic |

---

## Sources

- [AVCaptureSession and AVAudioSession — Apple Developer Forums (thread 61594)](https://developer.apple.com/forums/thread/61594)
- [automaticallyConfiguresApplicationAudioSession — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturesession/automaticallyconfiguresapplicationaudiosession)
- [Handling audio interruptions — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- [Responding to audio route changes — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)
- [AVCaptureSession.InterruptionReason.videoDeviceNotAvailableInBackground — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturesession/interruptionreason/videodevicenotavailableinbackground)
- [AVCaptureMovieFileOutput recordedDuration Value is Inaccurate — twocentstudios.com (2025)](https://twocentstudios.com/2025/02/06/avcapturemoviefileoutput-recordedduration-is-inaccurate/)
- [iOS: Recording from two AVCaptureSessions is out of sync — Apple Developer Forums (thread 742022)](https://forums.developer.apple.com/forums/thread/742022)
- [AVCaptureMovieFileOutput vs AVAssetWriter — Apple Developer Forums (thread 73800)](https://developer.apple.com/forums/thread/73800)
- [Comparison between AVCaptureMovieFileOutput and AVAssetWriter — tinyfool.org (2023)](https://tinyfool.org/2023/06/146/)
- [Capturing Video on iOS — objc.io](https://www.objc.io/issues/23-video/capturing-video/)
- [Handling Audio Sessions with Bluetooth in Swift — Atomic Object](https://spin.atomicobject.com/bluetooth-audio-sessions-swift/)
- [Introduce Multi-Camera Capture for iOS — WWDC19](https://developer.apple.com/videos/play/wwdc2019/249/)
- [Create a more responsive camera experience — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10105/)
- [Background audio handling with iOS AVPlayer — Mux](https://www.mux.com/blog/background-audio-handling-with-ios-avplayer)
- [App Store Review Guidelines — Apple](https://developer.apple.com/app-store/review/guidelines/)
- [SwiftUI VideoPlayer memory leak — Hacking with Swift Forums](https://www.hackingwithswift.com/forums/swiftui/swiftui-videoplayer-leaking-atstate-management-issue/25070)
- [iOS Camera AVCaptureAudioDataOutput activate audio — Apple Developer Forums (thread 681319)](https://developer.apple.com/forums/thread/681319)
- [Can I continue recording video when the app is backgrounded? — Apple Developer Forums (thread 61406)](https://developer.apple.com/forums/thread/61406)

---
*Pitfalls research for: Native iOS AVPlayer + AVCaptureSession simultaneous video recording and playback (Mimzit)*
*Researched: 2026-03-25*
