---
phase: quick
plan: 260328-pyp
type: execute
wave: 1
depends_on: []
files_modified:
  - Mimzit/Features/Recording/RecordingViewModel.swift
  - Mimzit/Features/Recording/RecordingView.swift
  - project.yml
  - Mimzit.xcodeproj/project.pbxproj
autonomous: true
requirements: []

must_haves:
  truths:
    - "Speaker mute button is visible in the recording screen bottom panel"
    - "Tapping the button toggles mute/unmute and the icon changes accordingly"
    - "When muted, reference audio (playbackEngine volume) is set to 0"
    - "When unmuted, reference audio is restored to 1.0 (or respects audioBlend if not recording)"
    - "Default state is unmuted"
    - "Mute state is preserved during recording but the button is still visible and tappable"
  artifacts:
    - path: "Mimzit/Features/Recording/RecordingViewModel.swift"
      provides: "isMuted Bool property + toggleMute() method"
    - path: "Mimzit/Features/Recording/RecordingView.swift"
      provides: "Speaker mute toggle button in bottomPanel"
    - path: "project.yml"
      provides: "MARKETING_VERSION 0.0.5, CURRENT_PROJECT_VERSION 5"
  key_links:
    - from: "RecordingView mute button"
      to: "RecordingViewModel.isMuted"
      via: "viewModel.toggleMute() on tap"
    - from: "RecordingViewModel.isMuted"
      to: "PlaybackEngine.volume"
      via: "toggleMute() sets volume 0 or 1 directly"
---

<objective>
Add a speaker mute/unmute toggle to the recording screen so users can silence reference audio mid-session without losing the recording. Also bump the app to v0.0.5 (build 5) and cut a GitHub release.

Purpose: Reference audio can be distracting or loud in certain environments; a one-tap mute gives immediate control without touching the fader.
Output: Mute toggle button in bottomPanel, isMuted state on ViewModel, version bump, GitHub release v0.0.5.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

<!-- Key interfaces the executor needs: -->
<interfaces>
<!-- From Mimzit/Engines/PlaybackEngine.swift -->
```swift
@Observable @MainActor final class PlaybackEngine {
    var volume: Float = 1.0 { didSet { player.volume = volume } }
}
```

<!-- From Mimzit/Features/Recording/RecordingViewModel.swift (relevant section) -->
```swift
// audioBlend: 0.0 = full reference, 1.0 = muted reference
var audioBlend: Float = 0.0

func updateAudioBlend() {
    if isRecording {
        playbackEngine.volume = 1.0
    } else {
        playbackEngine.volume = 1.0 - audioBlend
    }
}
// audioFaderVisible is hardcoded false (fader hidden on recording screen)
var audioFaderVisible: Bool { false }
```

<!-- From Mimzit/Features/Recording/RecordingView.swift (bottomPanel) -->
```swift
private var bottomPanel: some View {
    VStack(spacing: 12) {
        // Video fader
        FaderView(value: $viewModel.videoBlend, ...)
        // Audio fader (hidden: audioFaderVisible == false)
        // Speed control (text-only)
        // Record button
        recordButton
        Spacer().frame(height: 16)
    }
    .padding(...)
    .background(Theme.overlayPanel)
    ...
}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add isMuted state and toggleMute to RecordingViewModel</name>
  <files>Mimzit/Features/Recording/RecordingViewModel.swift</files>
  <action>
Add the following to RecordingViewModel:

1. New stored property in the "UI State" section:
```swift
/// Whether reference audio is muted. Default false (unmuted). (MUTE-01)
var isMuted: Bool = false
```

2. New method in the "Fader Updates" section after `updateAudioBlend()`:
```swift
/// Toggles reference audio mute on/off.
///
/// When muted: sets playbackEngine.volume to 0.0 regardless of recording state.
/// When unmuted: restores volume via updateAudioBlend() so recording vs. idle
/// semantics are preserved (1.0 during recording, 1.0 - audioBlend otherwise).
func toggleMute() {
    isMuted.toggle()
    if isMuted {
        playbackEngine.volume = 0.0
    } else {
        updateAudioBlend()
    }
}
```

3. In `fileOutput(_:didStartRecordingTo:...)` delegate method — the line that sets `self.playbackEngine.volume = 1.0` — guard against the muted state:
```swift
// Lock reference audio to full volume during recording UNLESS muted
if !self.isMuted {
    self.playbackEngine.volume = 1.0
}
```

No changes to `updateAudioBlend()` itself — when muted and recording stops, `updateAudioBlend()` is called from `toggleRecording()` stop path which will override the mute. To handle this correctly, also update `updateAudioBlend()` to respect mute:
```swift
func updateAudioBlend() {
    guard !isMuted else { return }
    if isRecording {
        playbackEngine.volume = 1.0
    } else {
        playbackEngine.volume = 1.0 - audioBlend
    }
}
```
  </action>
  <verify>Build succeeds: open Xcode or run `xcodebuild -scheme Mimzit -destination 'generic/platform=iOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5`</verify>
  <done>RecordingViewModel has `isMuted: Bool = false`, `toggleMute()` method, and `updateAudioBlend()` respects muted state. Build is clean.</done>
</task>

<task type="auto">
  <name>Task 2: Add mute toggle button to RecordingView bottomPanel + bump version + release</name>
  <files>Mimzit/Features/Recording/RecordingView.swift, project.yml, Mimzit.xcodeproj/project.pbxproj</files>
  <action>
**Part A — Mute button in RecordingView**

In `bottomPanel`, add a mute toggle button above the record button. The button sits in an HStack to keep it unobtrusive. Insert after the audio fader block and before the speed control / record button:

```swift
// Speaker mute toggle (hidden for text-only content)
if !viewModel.isTextOnlyContent {
    HStack {
        Spacer()
        Button {
            viewModel.toggleMute()
        } label: {
            Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isMuted ? Theme.recordActive : .white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.45))
                .clipShape(Circle())
        }
        .accessibilityLabel(viewModel.isMuted ? "Unmute reference audio" : "Mute reference audio")
    }
}
```

Place this block between the audio fader `if viewModel.audioFaderVisible { ... }` block and the speed control `if viewModel.isTextOnlyContent { ... }` block. This keeps layout order: video fader → (audio fader if visible) → mute button (if video content) → (speed if text-only) → record button.

Use `Theme.recordActive` for the muted icon color (red) to make the muted state visually obvious, consistent with the existing recording active color.

**Part B — Version bump**

In `project.yml`, update:
```yaml
MARKETING_VERSION: "0.0.5"
CURRENT_PROJECT_VERSION: "5"
```

Then run `xcodegen generate` to regenerate `Mimzit.xcodeproj/project.pbxproj`.

**Part C — Git commit and GitHub release**

1. Stage and commit:
```bash
git add Mimzit/Features/Recording/RecordingViewModel.swift \
        Mimzit/Features/Recording/RecordingView.swift \
        project.yml \
        Mimzit.xcodeproj/project.pbxproj
git commit -m "feat: add speaker mute toggle to recording screen, bump to v0.0.5"
git push origin main
```

2. Get commits since last release for release notes:
```bash
git log v0.0.4..HEAD --oneline
```

3. Create GitHub release:
```bash
gh release create v0.0.5 \
  --title "v0.0.5 — Speaker mute toggle" \
  --notes "$(cat <<'EOF'
## What's New

- **Speaker mute toggle**: Tap the speaker icon in the recording controls to instantly mute/unmute reference audio. Icon turns red when muted. Works during and between recordings.

## Bug Fixes / Improvements

- None in this release

## Full Changelog
https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/compare/v0.0.4...v0.0.5
EOF
)"
```
  </action>
  <verify>
1. Build succeeds with no errors.
2. `gh release view v0.0.5` shows the release with correct title.
3. `git log --oneline -3` shows the version bump commit on main.
  </verify>
  <done>
- Mute button visible in bottomPanel for video/audio content (not text-only).
- Tapping toggles speaker icon between `speaker.wave.2.fill` (white) and `speaker.slash.fill` (red).
- v0.0.5 (build 5) committed, pushed, and GitHub release v0.0.5 created.
  </done>
</task>

</tasks>

<verification>
- `isMuted` defaults to `false` — reference audio plays at normal volume on screen open.
- `toggleMute()` when muted sets `playbackEngine.volume = 0.0`; when unmuted calls `updateAudioBlend()` to restore correct volume for current state.
- `updateAudioBlend()` early-returns if `isMuted == true` — prevents recording start/stop events from accidentally un-muting.
- `fileOutput(_:didStartRecordingTo:...)` guards volume restoration with `!isMuted`.
- Mute button is hidden for `.isTextOnlyContent` (no reference audio in text-only mode).
- GitHub release v0.0.5 exists and is visible via `gh release view v0.0.5`.
</verification>

<success_criteria>
- Mute button appears in recording screen bottom panel for video/audio content.
- Tapping mutes reference audio immediately (volume drops to 0), icon changes to speaker.slash.fill in red.
- Tapping again unmutes (volume restores to 1.0 or respects audioBlend), icon returns to speaker.wave.2.fill in white.
- App version is 0.0.5 build 5 in project.yml and regenerated xcodeproj.
- `git push` succeeded and `gh release create v0.0.5` is live.
</success_criteria>

<output>
After completion, create `.planning/quick/260328-pyp-add-speaker-mute-toggle-to-recording-scr/260328-pyp-SUMMARY.md`
</output>
