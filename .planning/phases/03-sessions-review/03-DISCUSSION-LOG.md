# Phase 3: Sessions + Review - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 03-sessions-review
**Areas discussed:** Auto-save vs manual save, Review playback controls, Session history list, Progress comparison (REV-04)

---

## Auto-save vs Manual Save

### When recording finishes, what should happen?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-save immediately | Session saved the moment recording stops. No prompt, no discard. Simple flow. Delete from history later if unwanted. | ✓ |
| Save/discard prompt | After recording stops, show Save or Discard dialog. Lets user throw away bad takes but adds friction. | |
| Preview then save | Show mini review with Save/Redo/Discard. More polished but heavier flow. | |

**User's choice:** Auto-save immediately
**Notes:** None — straightforward preference for minimal friction.

### After a session is saved, what does the user see?

| Option | Description | Selected |
|--------|-------------|----------|
| Stay on recording screen | Session saved in background. Brief toast confirms save. Ready to record again. | ✓ |
| Navigate to review | Auto-open review screen for just-completed session. | |
| Return to content detail | Dismiss recording screen, return to content detail view. | |

**User's choice:** Stay on recording screen
**Notes:** None — tight practice loop preferred.

---

## Review Playback Controls

### How should the review screen differ from the recording screen?

| Option | Description | Selected |
|--------|-------------|----------|
| Same layout, playback controls | Reuse CompositorView + FaderView. Replace record button with play/pause. Add scrub bar. No camera — reference + user recording blended via fader. | ✓ |
| Simplified player | Standard video player with fader overlay. No view mode switching. | |
| Side-by-side view | Split screen: reference left, user recording right. Fader controls audio only. | |

**User's choice:** Same layout, playback controls
**Notes:** None.

### Should the fader labels change for review mode?

| Option | Description | Selected |
|--------|-------------|----------|
| REF / YOU | Video fader: REF/YOU. Audio fader: REF/YOU. Clear distinction. | ✓ |
| Keep REF / CAM | Same as recording mode. Consistent but 'CAM' misleading. | |
| REF / REC | REF/REC for both. Technical but unambiguous. | |

**User's choice:** REF / YOU
**Notes:** None.

---

## Session History List

### Where should the session history live?

| Option | Description | Selected |
|--------|-------------|----------|
| New Sessions tab | Third tab between Library and Settings. All sessions, sorted by date. | |
| Inside content detail | Sessions appear as list inside each content's detail view. | |
| Both | Sessions tab globally + content detail filtered. | |

**User's choice:** Sessions tab with filter-by-content + bidirectional navigation
**Notes:** User proposed: Sessions tab with ability to search/filter by content item. Content detail has a button that navigates to Sessions tab with pre-applied filter. Any session has a clickable link to the content detail to start practicing the same material. Bidirectional linking between content and sessions.

### What metadata should each session row show?

| Option | Description | Selected |
|--------|-------------|----------|
| Content title + date + duration | Reference content title, date/time, duration. Reference thumbnail on left. | ✓ |
| Add recording preview thumbnail | Same plus user recording thumbnail. Richer but requires thumbnail generation. | |
| Minimal — date + duration only | Just date/time and duration. Content title as section header. | |

**User's choice:** Content title + date + duration
**Notes:** None.

---

## Progress Comparison (REV-04)

### How should users compare progress across sessions?

| Option | Description | Selected |
|--------|-------------|----------|
| Chronological session list | Sessions filtered by content, sorted by date. User reviews sequentially. The fader review UI IS the comparison tool. | ✓ |
| Side-by-side dual review | Pick two sessions, play simultaneously. Powerful but complex. | |
| Defer to v2 | Mark REV-04 deferred. Filtered list gives enough context. | |

**User's choice:** Chronological session list
**Notes:** None.

## Claude's Discretion

- SwiftData schema migration (V1 → V2)
- Toast/banner animation for save confirmation
- Scrub bar design
- CompositorView adaptation for dual AVPlayerLayer
- Session row layout details
- Filter UI design in Sessions tab
- Recording thumbnail generation strategy

## Deferred Ideas

- Side-by-side dual session comparison — v2
- Recording preview thumbnails — v2
- Session notes/annotations — v2 (ORG-02)
- Session renaming — v2 (ORG-01)
- Export to Camera Roll — v2 (EXP-01, EXP-02)
