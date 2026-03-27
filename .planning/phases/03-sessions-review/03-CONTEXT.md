# Phase 3: Sessions + Review - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can save practice sessions (reference + user recording pair), view a filterable session history, and review any past session with the same fader playback UI used during recording. Sessions persist across app launches. Users can compare progress by reviewing sessions of the same reference content chronologically.

</domain>

<decisions>
## Implementation Decisions

### Session Saving
- **D-01:** Auto-save immediately when recording stops (user taps stop or reference video ends). No save/discard prompt. User can delete from history later. Minimizes friction in the practice loop.
- **D-02:** After auto-save, stay on the recording screen. A brief toast/banner confirms the save. User is ready to record another take immediately without navigating away.
- **D-03:** Session data model stores: reference content link, recording filename (relative, via FileVault pattern), duration, syncTimestamp (from REC-05), recorded-at date. Follow the ReferenceContent pattern — binary files on disk, metadata in SwiftData.

### Review Playback
- **D-04:** Review screen reuses the same layout as the recording screen (CompositorView + FaderView). Replace the record button with play/pause. Add a scrub bar (timeline slider) for seeking. No camera preview — show reference video + user recording blended via fader.
- **D-05:** Fader labels change for review mode: video fader shows "REF" (left) / "YOU" (right). Audio fader shows "REF" / "YOU". Clear distinction that user is blending reference vs their own recording.
- **D-06:** View mode control available in review: Ref | You | Blend (no Text mode in review unless transcript exists, in which case Text is available). "Cam" label becomes "You" in review context.
- **D-07:** Audio fader works normally in review mode (controls reference volume blend). This is the behavior already implemented in Phase 2 — fader only affects playback when not recording.

### Session History
- **D-08:** New "Sessions" tab added between Library and Settings in the main TabView. Shows all sessions across all content, sorted by date (newest first). Mirrors ContentLibraryView pattern (@Query, swipe-to-delete with confirmation).
- **D-09:** Each session row shows: reference content title, date/time (e.g., "Mar 26, 2:30 PM"), duration (e.g., "01:24"), and reference content thumbnail on the left. Simple and scannable.
- **D-10:** Sessions tab supports filtering by content item. Content detail view has a "Sessions" button/link that navigates to the Sessions tab with a pre-applied filter showing only sessions for that content.
- **D-11:** Bidirectional navigation: Session row has a tappable link to the content detail (to start practicing the same material). Content detail links to filtered sessions. Both directions work.

### Progress Comparison (REV-04)
- **D-12:** Chronological session list filtered by content IS the comparison mechanism. User reviews sessions sequentially by date to see improvement. The fader-based review UI is the comparison tool — no separate comparison view needed.

### Carried Forward from Phase 2
- **D-13:** `syncTimestamp` (CACurrentMediaTime at recording start) persisted with session for accurate review playback alignment between reference and user recording.
- **D-14:** `lastRecordingURL` from RecordingViewModel provides the file to move into permanent storage when auto-saving.
- **D-15:** PlaybackEngine reused directly for review playback. CompositorView reused with two AVPlayerLayers (reference + user recording) instead of AVPlayerLayer + AVCaptureVideoPreviewLayer.

### Claude's Discretion
- SwiftData schema migration approach (V1 → V2 with Session model)
- Toast/banner animation and timing for save confirmation
- Scrub bar visual design and interaction details
- How to handle the CompositorView adaptation for two AVPlayerLayers (review mode)
- Session row layout specifics (font sizes, spacing, thumbnail size)
- Filter UI design in Sessions tab (chip, search bar, or segmented control)
- Whether to generate recording thumbnails or reuse reference thumbnails

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 2 Codebase (Direct Reuse)
- `Mimzit/Features/Recording/CompositorView.swift` — CALayer compositor to adapt for review (two AVPlayerLayers)
- `Mimzit/Features/Recording/FaderView.swift` — Fader UI reused directly in review
- `Mimzit/Features/Recording/RecordingView.swift` — Layout pattern for review screen
- `Mimzit/Features/Recording/RecordingViewModel.swift` — Recording flow, lastRecordingURL, syncTimestamp
- `Mimzit/Engines/PlaybackEngine.swift` — AVPlayer wrapper for review playback
- `Mimzit/Engines/CaptureEngine.swift` — syncTimestamp() method
- `Mimzit/Models/ViewMode.swift` — View mode enum (adapt for review: Ref/You/Blend/Text)

### Phase 1 Codebase (Patterns to Mirror)
- `Mimzit/Models/ReferenceContent.swift` — SwiftData model pattern for Session model
- `Mimzit/Models/MimzitMigrationPlan.swift` — Schema versioning pattern for V2 migration
- `Mimzit/Features/Import/ContentLibraryView.swift` — List view pattern (@Query, swipe-delete, rows) for SessionHistoryView
- `Mimzit/Features/Import/ContentDetailView.swift` — Detail view pattern, navigation to recording
- `Mimzit/Services/FileVault.swift` — File storage pattern (relative filenames in SwiftData)
- `Mimzit/App/ContentView.swift` — TabView structure to add Sessions tab
- `Mimzit/Shared/Theme.swift` — Semantic color system

### Architecture Documentation
- `.planning/research/ARCHITECTURE.md` — AVFoundation architecture, dual-player sync approach
- `CLAUDE.md` — Stack decisions, review screen composition approach
- `.planning/REQUIREMENTS.md` — SESS-01 through REV-04 requirement details

### Prior Phase Context
- `.planning/phases/02-recording-fader-view-modes/02-CONTEXT.md` — Phase 2 decisions (fader design, view modes, auto-hide)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **CompositorView:** Adapt for review — replace AVCaptureVideoPreviewLayer with a second AVPlayerLayer for user recording
- **FaderView:** Direct reuse with label changes (REF/YOU instead of REF/CAM)
- **PlaybackEngine:** Create two instances for review — one for reference, one for user recording
- **ContentLibraryView pattern:** @Query, ForEach, swipe-to-delete, confirmation alerts — mirror for SessionHistoryView
- **FileVault:** Extend with session-specific storage (move recording from temp to permanent)
- **Theme:** All recording colors reusable for review UI

### Established Patterns
- **@Observable @MainActor services:** Use for ReviewViewModel
- **UIViewRepresentable:** CompositorView pattern for dual-player review
- **SwiftData @Query:** ContentLibraryView pattern for session list
- **Schema versioning:** MimzitMigrationPlan pattern for V2

### Integration Points
- **RecordingViewModel → Session save:** After recording stops, create Session record + move file to permanent storage
- **ContentView TabView:** Add SessionHistoryView as middle tab
- **ContentDetailView:** Add "Sessions" button linking to filtered session list
- **SessionRow → ContentDetailView:** Tappable link back to content for re-practice

</code_context>

<specifics>
## Specific Ideas

- Bidirectional navigation between content and sessions is important — user should flow seamlessly between "I want to practice this" and "let me review my past attempts"
- Auto-save + stay-on-screen creates a tight practice loop: record, save (background), record again
- The review screen IS the comparison tool — no separate comparison view needed for v1
- Two PlaybackEngine instances for review need synchronized playback using the persisted syncTimestamp

</specifics>

<deferred>
## Deferred Ideas

- Side-by-side dual session comparison (pick two sessions, play simultaneously) — v2 scope
- Recording preview thumbnails generated from user video — v2 scope
- Session notes/annotations — v2 (ORG-02)
- Session renaming — v2 (ORG-01)
- Export to Camera Roll — v2 (EXP-01, EXP-02)

</deferred>

---

*Phase: 03-sessions-review*
*Context gathered: 2026-03-27*
