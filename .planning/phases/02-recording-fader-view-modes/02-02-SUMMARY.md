---
phase: 02-recording-fader-view-modes
plan: 02
subsystem: recording-ui-components
tags: [swiftui, avfoundation, calayer, uiviewrepresentable, draggesture, haptics, teleprompter]

# Dependency graph
requires:
  - phase: 02-recording-fader-view-modes
    plan: 01
    provides: CaptureEngine (previewLayer), PlaybackEngine (playerLayer), ViewMode enum, Theme recording colors

provides:
  - CompositorView: UIViewRepresentable CALayer stack with CATransaction-guarded opacity fader blend
  - FaderView: custom DragGesture horizontal slider with haptic snap at 0/50/100%, configurable track height
  - ViewModeControl: 4-segment pill control (Ref/Cam/Blend/Text) with accent selection, Text gated on hasTranscript
  - TeleprompterView: Timer.publish auto-scroll via ScrollViewReader with current-line 28pt highlight, full-screen and overlay modes

affects:
  - 02-03 (RecordingView assembles all 4 components into the full recording screen)

# Tech stack
tech_stack:
  added: []
  patterns:
    - UIViewRepresentable with CATransaction.setDisableActions(true) for GPU-composited layer blending
    - GeometryReader + DragGesture for custom slider with edge-triggered haptic snap points
    - Timer.publish + ScrollViewReader for teleprompter auto-scroll driven by isScrolling binding
    - ForEach(ViewMode.allCases) for declarative segmented control

# Key files
key_files:
  created:
    - Mimzit/Features/Recording/CompositorView.swift
    - Mimzit/Features/Recording/FaderView.swift
    - Mimzit/Features/Recording/ViewModeControl.swift
    - Mimzit/Features/Recording/TeleprompterView.swift
  modified: []

# Decisions
decisions:
  - Edge-trigger haptic snap: tracks `firedSnapPoints` per drag to fire each snap point only once per pass (not level-trigger)
  - Fractional line index: TeleprompterView uses a `fractionalIndex: Double` accumulator to enable sub-line scroll speed increments smaller than 1 line per timer tick
  - Non-empty line preservation: lines array retains empty strings after split to preserve paragraph spacing; trimmed only for whitespace
  - Overlay padding alignment: non-current lines in full-screen mode use `padding(.leading, 12)` to align with the accent bar width (4px) + spacing (8px)

# Metrics
metrics:
  duration: 8m
  completed_date: "2026-03-26T22:28:06Z"
  tasks_completed: 2
  files_created: 4
  files_modified: 0
---

# Phase 02 Plan 02: Recording UI Components Summary

**One-liner:** Four SwiftUI recording components (CompositorView CALayer stack, FaderView drag slider with haptics, ViewModeControl pill segments, TeleprompterView auto-scroll) ready for RecordingView assembly in Plan 03.

## What Was Built

### CompositorView (`Mimzit/Features/Recording/CompositorView.swift`)

`struct CompositorView: UIViewRepresentable` that bridges two AVFoundation CALayers into SwiftUI.

- `AVPlayerLayer` (reference video) is placed as the bottom sublayer with `.resizeAspectFill` gravity
- `AVCaptureVideoPreviewLayer` is placed as the top sublayer — optional to handle CaptureEngine's async initialization
- `updateUIView` wraps ALL frame and opacity mutations in `CATransaction.begin()` / `CATransaction.setDisableActions(true)` / `CATransaction.commit()` — prevents implicit CALayer animations on every SwiftUI re-render and fader drag (Pitfall 3)
- `previewLayer?.opacity = videoBlend` is the single line that drives the live fader blend — GPU-composited by the system at zero CPU cost (FADER-04)
- Late-init guard: `if previewLayer.superlayer == nil { uiView.layer.addSublayer(previewLayer) }` handles the CaptureEngine async configure pattern from Plan 01

### FaderView (`Mimzit/Features/Recording/FaderView.swift`)

`struct FaderView: View` — pure SwiftUI `GeometryReader` + `DragGesture`.

- Configurable `trackHeight: CGFloat` — 8pt for video fader, 4pt for audio fader (UI-SPEC)
- Track background (`Theme.faderTrack`), filled track (`Theme.faderFilled`), 28pt white thumb with shadow
- `contentShape(Rectangle())` on the 44pt hit target makes the full area draggable (not just the thumb)
- Edge-triggered haptic snap: `firedSnapPoints: Set<Float>` tracks which of [0.0, 0.5, 1.0] have fired during the current drag; fires `UIImpactFeedbackGenerator(style: .light)` only when crossing within ±0.02 of an unfired snap point
- `leftLabel`/`rightLabel` overlaid at bottom edge with `offset(y: 12)` below the track
- `Float.clamped(to:)` private extension prevents out-of-bounds drag values

### ViewModeControl (`Mimzit/Features/Recording/ViewModeControl.swift`)

`struct ViewModeControl: View` — pill-shaped segmented control.

- `ForEach(ViewMode.allCases, id: \.self)` renders 4 segments using the enum's `rawValue` as label text
- Selected segment: `Theme.accent` capsule background, 13pt Semibold white
- Unselected segment: transparent background, 13pt Regular `Theme.dimmedText`
- Text segment: `.disabled(!hasTranscript)` + `.opacity(hasTranscript ? 1.0 : 0.35)` when no transcript (VIEW-03)
- Tap: `withAnimation(.easeInOut(duration: 0.20)) { selected = mode }` (UI-SPEC interaction contract)
- Container: `.ultraThinMaterial` + `Theme.controlBg` background, `.clipShape(Capsule())` for full pill shape

### TeleprompterView (`Mimzit/Features/Recording/TeleprompterView.swift`)

`struct TeleprompterView: View` with full-screen and overlay rendering modes.

- `text` split by newlines; each line rendered in `ForEach` with `.id(index)` for `ScrollViewReader`
- Current line (index matches `currentLineIndex`): 28pt Semibold white + 4px `Theme.accent` left bar
- Non-current lines: 16pt Regular `Theme.teleprompterDim` (50% white opacity)
- All text has `.shadow(color: .black.opacity(0.6), radius: 2)` for legibility over video (UI-SPEC typography)
- Auto-scroll: `Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()` — guarded by `isScrolling`, advances `fractionalIndex` by `scrollSpeed * 0.015` per tick, scrolls with `withAnimation(.linear(duration: 0.05))`
- Speed control: `Slider(value: $scrollSpeed, in: 1...4, step: 0.5)` labeled "Speed" — visible in full-screen mode only
- `onChange(of: text)` resets `currentLineIndex = 0` and `fractionalIndex = 0.0`

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all components fully implement their specified behavior.

## Self-Check: PASSED

Files exist:
- FOUND: Mimzit/Features/Recording/CompositorView.swift
- FOUND: Mimzit/Features/Recording/FaderView.swift
- FOUND: Mimzit/Features/Recording/ViewModeControl.swift
- FOUND: Mimzit/Features/Recording/TeleprompterView.swift

Commits exist:
- FOUND: 879b97b (CompositorView + FaderView)
- FOUND: 3ace9c0 (ViewModeControl + TeleprompterView)

Build: SUCCEEDED (xcodebuild, iPhone 17 Pro simulator, iOS 26.2)
