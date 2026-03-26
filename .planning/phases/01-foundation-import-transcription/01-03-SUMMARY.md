---
phase: 01-foundation-import-transcription
plan: 03
subsystem: ui
tags: [swiftui, avfoundation, whisper, openai, keychain, swiftdata, transcription]

# Dependency graph
requires:
  - phase: 01-01
    provides: TranscriptionService, WhisperAPIClient, AudioPreprocessor, KeychainService
  - phase: 01-02
    provides: ContentDetailView (placeholder transcription section), ContentLibraryView, SettingsView

provides:
  - TranscribeButtonView — four-state button component (idle, inProgress, complete, error)
  - APIKeyPromptSheet — lazy API key entry sheet with auto-retry on save
  - ContentDetailView updated with live TranscriptionService integration and full error handling
  - Complete end-to-end transcription flow: tap -> progress -> transcript saved to SwiftData

affects:
  - phase-02-recording (ContentDetailView Start Practice button wired from transcript state)
  - phase-03-review (transcript overlay data source wired here)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Three-state UI component pattern (idle/inProgress/complete/error enum) for async operations
    - Lazy credential prompt pattern: show API key sheet on first-use demand, auto-retry on save
    - Task-based async error dispatch with typed error switch in ContentDetailView

key-files:
  created:
    - Mimzit/Features/Transcription/TranscribeButtonView.swift
    - Mimzit/Features/Transcription/APIKeyPromptSheet.swift
  modified:
    - Mimzit/Features/Import/ContentDetailView.swift
    - Mimzit.xcodeproj/project.pbxproj

key-decisions:
  - "TRANS-04 deferred per D-11 — no SFSpeechRecognizer on-device fallback; Whisper API is the only transcription path in Phase 1"
  - "API key lazy-prompt (D-13): APIKeyPromptSheet appears on demand when TranscriptionError.noAPIKey is caught; on save it auto-retries transcription via onSave callback"
  - "TranscribeState enum drives all button rendering — single enum value drives idle/progress/complete/error states, no boolean flags"

patterns-established:
  - "Three-state async operation: define enum (idle/inProgress/complete/error), set state in Task block, render via switch in View"
  - "Lazy credential gate: catch .noAPIKey error -> show sheet -> pass onSave callback -> dismiss+retry pattern"
  - "content.transcript = text writes directly to @Model SwiftData instance (TRANS-03)"

requirements-completed: [TRANS-01, TRANS-02, TRANS-03, TRANS-04, IMPORT-05]

# Metrics
duration: ~15min
completed: 2026-03-26
---

# Phase 1 Plan 03: Transcription UI Wiring Summary

**TranscribeButtonView (four-state), APIKeyPromptSheet (lazy key prompt with auto-retry), and ContentDetailView wired to TranscriptionService — completing Phase 1 end-to-end**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-26T12:55:00Z
- **Completed:** 2026-03-26T13:10:00Z
- **Tasks:** 2 (1 auto, 1 checkpoint — user approved)
- **Files modified:** 4

## Accomplishments

- TranscribeButtonView with four-state enum renders idle button, spinner+text, success label, and error message+retry button
- APIKeyPromptSheet triggers lazily when no OpenAI API key exists, saves to Keychain, and auto-retries transcription after dismiss
- ContentDetailView wired to TranscriptionService: async Task-based startTranscription(), typed error handling for noAPIKey/noNetwork/fileTooLarge/apiError
- TRANS-03 implemented: transcript text saved to ReferenceContent.transcript (SwiftData @Model) on success
- TRANS-04 explicitly excluded per D-11: no SFSpeechRecognizer references anywhere

## Task Commits

Each task was committed atomically:

1. **Task 1: TranscribeButtonView, APIKeyPromptSheet, wire transcription into ContentDetailView** - `16f9235` (feat)
2. **Task 2: Checkpoint — user approved Phase 1 visual verification** - (checkpoint, no code commit)

## Files Created/Modified

- `Mimzit/Features/Transcription/TranscribeButtonView.swift` — Four-state transcription button view with TranscribeState enum
- `Mimzit/Features/Transcription/APIKeyPromptSheet.swift` — Lazy API key entry sheet with SecureField/eye toggle, Keychain save, and onSave auto-retry callback
- `Mimzit/Features/Import/ContentDetailView.swift` — Added TranscriptionService integration, startTranscription() async Task, showAPIKeyPrompt sheet binding, per-error message mapping
- `Mimzit.xcodeproj/project.pbxproj` — Added new Transcription files to Xcode build target

## Decisions Made

- **TRANS-04 deferred (D-11):** On-device SFSpeechRecognizer fallback explicitly excluded. Only Whisper API path exists in Phase 1. No fallback complexity added.
- **Lazy key prompt (D-13):** APIKeyPromptSheet is NOT shown during onboarding. It appears on-demand when the user taps Transcribe Audio with no key configured. Saves to Keychain, calls onSave callback to auto-retry.
- **TranscribeState enum:** Single enum drives all rendering. No boolean flag accumulation. Error case carries message string directly.

## Deviations from Plan

None — plan executed exactly as written. All three files match the plan's code specifications. Build passed with zero errors.

## Issues Encountered

None.

## User Setup Required

**OpenAI API key is required for transcription.** Users must:
1. Go to Settings tab
2. Tap the API Key field under "OpenAI API"
3. Paste their key from platform.openai.com
4. Tap Save API Key

Alternatively, the key prompt sheet appears automatically when tapping Transcribe Audio without a key configured.

## Next Phase Readiness

Phase 1 is complete. All import and transcription flows are functional:
- Content Library with video/audio/script import
- Content Detail with media preview and metadata
- Transcription pipeline: TranscriptionService -> WhisperAPIClient -> AudioPreprocessor -> Keychain
- Settings screen with API key management

Phase 2 (recording) can begin. ContentDetailView's Start Practice button is a no-op placeholder ready to be wired to the recording screen.

**Concern carried forward:** AirPods mic quality in .playAndRecord mode may be lower than expected (HFP vs A2DP); validate with physical device before shipping Phase 2.

## Self-Check: PASSED

- SUMMARY.md: FOUND
- Task commit 16f9235: FOUND

---
*Phase: 01-foundation-import-transcription*
*Completed: 2026-03-26*
