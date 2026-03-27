---
phase: 03-sessions-review
plan: 01
subsystem: persistence
tags: [swiftdata, session, filevault, recording, auto-save, migration, ios]

# Dependency graph
requires:
  - phase: 02-recording-fader-view-modes
    provides: RecordingViewModel (lastRecordingURL, syncTimestamp, recordingDuration), FileVault (recordingsDirectory pattern)
  - phase: 01-foundation-import-transcription
    provides: ReferenceContent (id, title pattern), MimzitMigrationPlan (V1 schema to extend), FileVault (static enum pattern)
provides:
  - Session: SwiftData @Model for practice sessions with all D-03 fields
  - MimzitSchemaV2: lightweight migration V1 -> V2 adding Session model
  - FileVault session extensions: sessionsDirectory, moveRecording, sessionURL, deleteSession
  - RecordingView auto-save: onChange trigger moves file + inserts Session into SwiftData
  - Toast banner: "Session Saved" confirmation after each recording stop
affects:
  - 03-02 (SessionHistoryView queries Session @Model for the sessions list)
  - 03-03 (ReviewView uses Session.recordingFilename + syncTimestamp for review playback)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SwiftData V2 lightweight migration: MimzitSchemaV2 adds Session.self; MimzitMigrationPlan.stages gets .lightweight(fromVersion: V1, toVersion: V2)"
    - "ModelContainer init updated to Schema([ReferenceContent.self, Session.self]) for multi-model support"
    - "Session denormalizes referenceContentTitle — plain UUID reference (not @Relationship) to avoid cascade-delete"
    - "FileVault sessions sub-directory pattern mirrors existing content/ and recordings/ directories"
    - "RecordingView uses onChange(of: lastRecordingURL) to trigger auto-save without ViewModel knowing about SwiftData"
    - "Toast banner driven by showSavedBanner Bool on ViewModel; withAnimation + Task.sleep for 2-second display"

key-files:
  created:
    - Mimzit/Models/Session.swift
  modified:
    - Mimzit/Models/MimzitMigrationPlan.swift
    - Mimzit/App/MimzitApp.swift
    - Mimzit/Services/FileVault.swift
    - Mimzit/Features/Recording/RecordingView.swift
    - Mimzit/Features/Recording/RecordingViewModel.swift
    - Mimzit.xcodeproj/project.pbxproj

key-decisions:
  - "No @Relationship from Session to ReferenceContent — plain UUID stored to avoid cascade-delete; referenceContentTitle denormalized for display without join"
  - "Auto-save wired in RecordingView (not RecordingViewModel) — ViewModel has no SwiftData dependency; modelContext stays in View layer"
  - "moveRecording (not copy) from recordings/ to sessions/ — avoids duplicate file; temp recordings/ is cleaned up by cleanupOldRecordings()"

requirements-completed: [SESS-01, SESS-04]

# Metrics
duration: 5min
completed: 2026-03-27
---

# Phase 3 Plan 1: Session Model, Migration, and Auto-Save Summary

**Session @Model with D-03 fields + SwiftData V2 lightweight migration + FileVault sessions directory + RecordingView onChange auto-save with toast confirmation — project compiles**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-27T00:37:08Z
- **Completed:** 2026-03-27T00:42:08Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Created `Session.swift` with all D-03 fields: id, recordedAt, duration, syncTimestamp, recordingFilename, referenceContentID (UUID, no @Relationship), referenceContentTitle (denormalized)
- Added `MimzitSchemaV2` with `[ReferenceContent.self, Session.self]`; registered `.lightweight(fromVersion: MimzitSchemaV1.self, toVersion: MimzitSchemaV2.self)` migration stage
- Updated `MimzitApp.swift` to use `Schema([ReferenceContent.self, Session.self])` in `ModelContainer` init
- Extended `FileVault` with `sessionsDirectory`, `moveRecording(from:filename:)`, `sessionURL(for:)`, `deleteSession(filename:)` — permanent session storage pattern mirrors existing content/ and recordings/ directories
- Added `showSavedBanner` and `showSaveConfirmation()` to `RecordingViewModel` — 2-second animated toast with easeIn/easeOut
- Wired `onChange(of: viewModel.lastRecordingURL)` in `RecordingView` → `saveSession()` method moves file via `FileVault.moveRecording`, creates `Session`, inserts into `modelContext`, calls `showSaveConfirmation()`
- Toast banner overlays the ZStack with checkmark icon and "Session Saved" text; transitions with `.move(edge: .top).combined(with: .opacity)`

## Task Commits

Each task was committed atomically:

1. **Task 1: Session model, V2 migration, FileVault session extensions** - `a56a041` (feat)
2. **Task 2: Auto-save wiring in RecordingView + toast banner** - `b6093ed` (feat)

## Files Created/Modified

- `Mimzit/Models/Session.swift` — @Model with all D-03 fields, no @Relationship, denormalized title
- `Mimzit/Models/MimzitMigrationPlan.swift` — MimzitSchemaV2 added, lightweight migration V1→V2 registered
- `Mimzit/App/MimzitApp.swift` — ModelContainer updated to Schema([ReferenceContent.self, Session.self])
- `Mimzit/Services/FileVault.swift` — sessionsDirectory, moveRecording, sessionURL, deleteSession added
- `Mimzit/Features/Recording/RecordingView.swift` — import SwiftData, modelContext env, onChange trigger, saveSession(), toast banner overlay
- `Mimzit/Features/Recording/RecordingViewModel.swift` — showSavedBanner, showSaveConfirmation()
- `Mimzit.xcodeproj/project.pbxproj` — Session.swift added to Models group and Sources build phase

## Decisions Made

- No `@Relationship` to `ReferenceContent` from `Session` — plain `referenceContentID: UUID` stored to prevent cascade-delete when reference content is deleted. `referenceContentTitle` denormalized for display without requiring a join fetch.
- Auto-save logic lives in `RecordingView` (not `RecordingViewModel`) — keeps the ViewModel free of SwiftData dependencies. The View owns the `modelContext` environment injection and calls `saveSession()` from within its task closure.
- `FileVault.moveRecording` uses `FileManager.moveItem` (not copy) — the temp `recordings/` file is consumed and relocated to permanent `sessions/` storage in one atomic operation, avoiding duplicates.

## Deviations from Plan

None — plan executed exactly as written. Session.swift required manual addition to Xcode project pbxproj (standard procedure for new Swift files in this codebase, not a deviation).

## Known Stubs

None — all Session fields are wired to real data (duration from recordingDuration, syncTimestamp from captureEngine, referenceContentID/Title from content). Toast banner is functional (not placeholder). No stub values flowing to UI.

## Self-Check: PASSED

All key files exist and commits are verified:
- Mimzit/Models/Session.swift — FOUND
- Mimzit/Models/MimzitMigrationPlan.swift — FOUND (contains MimzitSchemaV2)
- Mimzit/Services/FileVault.swift — FOUND (contains sessionsDirectory)
- Mimzit/App/MimzitApp.swift — FOUND (contains Session.self)
- Commit a56a041 (Task 1) — FOUND
- Commit b6093ed (Task 2) — FOUND
- xcodebuild BUILD SUCCEEDED
