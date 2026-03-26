# Phase 2: Recording + Fader + View Modes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-26
**Phase:** 02-recording-fader-view-modes
**Areas discussed:** Recording screen layout, Fader interaction design, View mode switching, Teleprompter behavior

---

## Recording Screen Layout

### Screen structure?

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen video with overlay controls | Reference fills screen. Camera overlays. Controls float at bottom. | :white_check_mark: |
| Split layout with controls panel | Video top 70%, controls bottom 30%. | |
| You decide | Claude picks. | |

**User's choice:** Full-screen video with overlay controls

### Navigation to recording screen?

| Option | Description | Selected |
|--------|-------------|----------|
| From 'Start Practice' on ContentDetailView | Tap content > detail > Start Practice > full-screen recording. | :white_check_mark: |
| Direct from library | Long-press or button on library item. | |
| You decide | Claude picks. | |

**User's choice:** From 'Start Practice' on ContentDetailView

### Record button position?

| Option | Description | Selected |
|--------|-------------|----------|
| Center bottom, large circular | Classic camera pattern. Red circle. Pulsing when recording. | :white_check_mark: |
| Side button | Right edge, like pro camera apps. | |
| You decide | Claude picks. | |

**User's choice:** Center bottom, large circular

### Auto-hide controls?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, auto-hide after 3 seconds | Fade out during recording. Tap to show. Faders stay while dragging. | :white_check_mark: |
| Always visible | Semi-transparent, always shown. | |
| You decide | Claude picks. | |

**User's choice:** Yes, auto-hide after 3 seconds

---

## Fader Interaction Design

### Video fader design?

| Option | Description | Selected |
|--------|-------------|----------|
| Horizontal slider at bottom | Above record button. Left=ref, center=blend, right=camera. CALayer opacity. | :white_check_mark: |
| Vertical slider on side | Right edge vertical. DJ-style. May conflict with swipe gestures. | |
| You decide | Claude picks. | |

**User's choice:** Horizontal slider at bottom

### Separate video and audio faders?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, two separate sliders | Independent video + audio control. Matches FADER-01 + FADER-02. | :white_check_mark: |
| Single linked fader | One fader controls both. | |
| You decide | Claude picks. | |

**User's choice:** Yes, two separate sliders

### Default fader positions?

| Option | Description | Selected |
|--------|-------------|----------|
| Video: center, Audio: reference only | Immediately see comparison, hear what to mimic. | :white_check_mark: |
| Both at reference-only | Start seeing/hearing only reference. | |
| Both at center (50/50) | Equal blend of both. | |
| You decide | Claude picks. | |

**User's choice:** Video: center (50/50 blend), Audio: reference only

### Haptic feedback?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, at endpoints and center | Light tap at 0%, 50%, 100%. UIImpactFeedbackGenerator. | :white_check_mark: |
| No haptics | Silent fader. | |
| You decide | Claude picks. | |

**User's choice:** Yes, at endpoints and center

---

## View Mode Switching

### How to switch between 4 view modes?

| Option | Description | Selected |
|--------|-------------|----------|
| Pill-shaped segmented control | Floating pill at top: Ref, Cam, Blend, Text. Tap to switch. | :white_check_mark: |
| Swipe between modes | Horizontal swipe cycles modes. | |
| Menu button with popup | Single button opens popup with 4 options. | |
| You decide | Claude picks. | |

**User's choice:** Pill-shaped segmented control

### Text overlay fader behavior?

| Option | Description | Selected |
|--------|-------------|----------|
| Context-sensitive fader | In text mode, video fader controls text opacity instead. Audio fader unchanged. | :white_check_mark: |
| Fader always controls video | Text at fixed opacity. Fader has no effect in text mode. | |
| You decide | Claude picks. | |

**User's choice:** Context-sensitive fader

---

## Teleprompter Behavior

### Scroll behavior?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-scroll with speed control | Auto-scroll on record start. Speed via slider or +/-. Pauses with recording. | :white_check_mark: |
| Manual scroll only | User scrolls with finger while recording. | |
| You decide | Claude picks. | |

**User's choice:** Auto-scroll with speed control

### Visual style?

| Option | Description | Selected |
|--------|-------------|----------|
| Dark background, large white text | Classic teleprompter. Dark bg, white text, current line highlighted, centered. | :white_check_mark: |
| Semi-transparent over camera | Text overlays on camera feed. More immersive but harder to read. | |
| You decide | Claude picks. | |

**User's choice:** Dark background, large white text

---

## Claude's Discretion

- CaptureEngine implementation details
- Animation timing for control auto-hide/show
- Fader thumb size and visual design
- View mode transition animations
- Teleprompter font size and line spacing
- Recording file naming and temp storage

## Deferred Ideas

- Session saving — Phase 3
- Review playback with fader — Phase 3
- Playback speed control — v2
- Loop in/out points — v2
