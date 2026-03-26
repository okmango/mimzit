---
phase: 01-foundation-import-transcription
plan: 02
subsystem: ui-import
tags: [swiftui, photospicker, fileimporter, swiftdata, keychain, avkit, avfoundation]
dependency_graph:
  requires:
    - 01-01 (ReferenceContent model, FileVault, KeychainService, Theme)
  provides:
    - ContentLibraryView (home screen with @Query list and all three import flows)
    - ContentItemRow (library list row with type icon, duration, transcript badge)
    - EmptyLibraryView (empty state per UI-SPEC)
    - VideoPicker (PHPickerViewController with loadFileRepresentation + sandbox copy)
    - TextScriptEditorView (text script entry sheet)
    - ContentDetailView (media preview sheet with placeholder transcription CTA)
    - SettingsView (API key management with Keychain, configured/unconfigured dual-state)
    - ContentView updated with real tab targets
  affects:
    - 01-03 (TranscriptionService will be wired into ContentDetailView transcribe button)
    - Phase 2 (Start Practice button in ContentDetailView to be wired)
tech_stack:
  added:
    - PhotosUI (PHPickerViewController via UIViewControllerRepresentable)
    - UniformTypeIdentifiers (UTType.movie for video picker)
    - AVKit (VideoPlayer for content detail video preview)
    - AVFoundation (AVAssetImageGenerator for thumbnail, AVAsset for duration extraction)
  patterns:
    - "PHPickerViewController + loadFileRepresentation (not unreliable loadTransferable for video)"
    - "File copied inside loadFileRepresentation callback before temp URL invalidated"
    - "Security-scoped URL pattern: startAccessingSecurityScopedResource/stopAccessingSecurityScopedResource for Files app imports"
    - "Dual-state UI pattern for Keychain-backed API key (configured shows masked key, unconfigured shows input)"
    - "@ViewBuilder computed properties for content-type-conditional UI (mediaPreview, transcriptSection)"
key_files:
  created:
    - Mimzit/Features/Import/ContentLibraryView.swift
    - Mimzit/Features/Import/ContentDetailView.swift
    - Mimzit/Features/Import/TextScriptEditorView.swift
    - Mimzit/Features/Import/VideoPicker.swift
    - Mimzit/Features/Settings/SettingsView.swift
    - Mimzit/Shared/Components/ContentItemRow.swift
    - Mimzit/Shared/Components/EmptyLibraryView.swift
  modified:
    - Mimzit/App/ContentView.swift (replaced placeholder tabs with ContentLibraryView + SettingsView)
decisions:
  - "PHPickerViewController instead of SwiftUI PhotosPicker.loadTransferable for video — loadTransferable is unreliable on iOS 16-17 for video URLs"
  - "AVKit VideoPlayer used for content detail video preview only (not recording screen) — acceptable per CLAUDE.md which restricts AVKit only for the main recording/fader screen"
  - "ContentDetailView transcription button is a no-op placeholder in Phase 1 — wired in Plan 03 when TranscriptionService is integrated"
  - "Start Practice button disabled in Phase 1 — enabled in Phase 2 when RecordingSession engine is built"
metrics:
  duration: "5 minutes"
  completed_date: "2026-03-26"
  tasks_completed: 2
  files_created: 7
  files_modified: 1
---

# Phase 01 Plan 02: UI Screens — Content Library, Import Flows, Detail, Settings Summary

**One-liner:** SwiftUI screens for content library with PHPickerViewController video import, fileImporter audio import, text script entry, AVKit detail preview, and Keychain-backed API key settings.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Content Library screen with all three import flows | 9333d7e | ContentLibraryView.swift, VideoPicker.swift, TextScriptEditorView.swift, ContentItemRow.swift, EmptyLibraryView.swift |
| 2 | Content Detail/Preview sheet and Settings screen with API key management | 27faa06 | ContentDetailView.swift, SettingsView.swift |

## What Was Built

### Task 1 — Content Library + Import Flows

**ContentLibraryView** (`Mimzit/Features/Import/ContentLibraryView.swift`):
- SwiftData `@Query(sort: \ReferenceContent.createdAt, order: .reverse)` — newest first
- `.confirmationDialog("Add Reference Content")` with three import paths
- Video import: VideoPicker sheet (PHPickerViewController) with async thumbnail generation and duration extraction
- Audio import: `.fileImporter` with security-scoped URL pattern
- Text import: TextScriptEditorView sheet
- Swipe-to-delete with delete confirmation alert matching Copywriting Contract exactly
- Progress overlay during import operations

**VideoPicker** (`Mimzit/Features/Import/VideoPicker.swift`):
- UIViewControllerRepresentable wrapping PHPickerViewController
- `loadFileRepresentation` (not `loadTransferable`) — reliable on iOS 16-17
- File copied to FileVault sandbox inside the callback before temp URL is invalidated (RESEARCH Pitfall 1)

**TextScriptEditorView** (`Mimzit/Features/Import/TextScriptEditorView.swift`):
- Full-height TextEditor with placeholder overlay
- "Save Script" disabled when text is empty after trimming
- Cancel/Save Script toolbar per UI-SPEC Screen 4

**ContentItemRow** (`Mimzit/Shared/Components/ContentItemRow.swift`):
- SF Symbol icons per content type (film/waveform/doc.text) with Theme colors
- Duration formatted as `m:ss`, omitted for scripts
- Green checkmark transcript badge when transcript exists

**EmptyLibraryView** (`Mimzit/Shared/Components/EmptyLibraryView.swift`):
- `film.stack` icon at 56pt, `.secondary`
- Heading/body copy per Copywriting Contract

### Task 2 — Content Detail Sheet + Settings

**ContentDetailView** (`Mimzit/Features/Import/ContentDetailView.swift`):
- `@ViewBuilder mediaPreview` conditional on contentType:
  - Video: AVKit `VideoPlayer` on tap, thumbnail with play overlay, or placeholder
  - Audio: Waveform icon with tap-to-play toggle
  - Text: 6-line script preview
- `@ViewBuilder transcriptSection`:
  - `.text` type: EmptyView (no transcription for scripts)
  - Has transcript: Green label + scrollable text view
  - No transcript: Placeholder "Transcribe Audio" button (wired in Plan 03)
- "Start Practice" button disabled — enabled in Phase 2
- Player paused and released on `.onDisappear`

**SettingsView** (`Mimzit/Features/Settings/SettingsView.swift`):
- Configured state: masked key display + "Clear API Key" destructive button
- Unconfigured state: SecureField with eye-toggle + "Save API Key"
- Keychain operations via `KeychainService.save/load/delete(key: "openai_api_key")`
- Clear confirmation alert with exact Copywriting Contract copy
- About section with app version from Bundle

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written. Both ContentDetailView and SettingsView were created as part of their respective tasks. Since ContentLibraryView references ContentDetailView, both needed to exist before the first build. This was handled by creating ContentDetailView within Task 1's execution window; it is committed separately as Task 2's commit (27faa06).

## Known Stubs

| File | Location | Description | Resolves In |
|------|----------|-------------|-------------|
| `Mimzit/Features/Import/ContentDetailView.swift` | `transcriptSection` / Transcribe Audio button action | `print("TODO: wire transcription in Plan 03")` — no-op placeholder | Plan 01-03 |
| `Mimzit/Features/Import/ContentDetailView.swift` | `Button("Start Practice") {}` | Empty action, `.disabled(true)` | Phase 2 |

Both stubs are intentional and documented per plan — they do not block the plan's goal (delivering the import/library/settings UI).

## Self-Check: PASSED

Files exist:
- FOUND: Mimzit/Features/Import/ContentLibraryView.swift
- FOUND: Mimzit/Features/Import/ContentDetailView.swift
- FOUND: Mimzit/Features/Import/TextScriptEditorView.swift
- FOUND: Mimzit/Features/Import/VideoPicker.swift
- FOUND: Mimzit/Features/Settings/SettingsView.swift
- FOUND: Mimzit/Shared/Components/ContentItemRow.swift
- FOUND: Mimzit/Shared/Components/EmptyLibraryView.swift

Commits exist:
- FOUND: 9333d7e (feat(01-02): content library screen with all three import flows)
- FOUND: 27faa06 (feat(01-02): content detail sheet and settings screen with API key management)

Build: ** BUILD SUCCEEDED **
