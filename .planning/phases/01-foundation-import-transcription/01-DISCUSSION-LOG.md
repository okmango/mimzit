# Phase 1: Foundation + Import + Transcription - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-25
**Phase:** 01-foundation-import-transcription
**Areas discussed:** Xcode project structure, Content import UX, Transcription workflow, API key setup flow

---

## Xcode Project Structure

### How should the Xcode project be set up?

| Option | Description | Selected |
|--------|-------------|----------|
| Single-target app | One app target, organized by feature folders. Simplest for solo dev. | :white_check_mark: |
| SPM modular packages | Local Swift packages (MimzitCore, MimzitUI, MimzitServices). Better compile times but more overhead. | |
| Tuist/XcodeGen managed | Use project.yml like sezit/digzit. Reproducible project files. | |

**User's choice:** Single-target app
**Notes:** None

### How should reusable code from sezit/digzit be brought in?

| Option | Description | Selected |
|--------|-------------|----------|
| Copy and adapt | Copy files into mimzit and adapt. No cross-project dependency. | :white_check_mark: |
| Shared local SPM package | Extract shared code into a local Swift package referenced by both projects. | |
| You decide | Claude picks the approach. | |

**User's choice:** Copy and adapt
**Notes:** None

### Should the project use project.yml (XcodeGen)?

| Option | Description | Selected |
|--------|-------------|----------|
| XcodeGen with project.yml | Consistent with other apps. Generated .xcodeproj gitignored. | :white_check_mark: |
| Standard .xcodeproj | No extra tooling. Xcode-native. | |

**User's choice:** XcodeGen with project.yml
**Notes:** None

### Folder organization?

| Option | Description | Selected |
|--------|-------------|----------|
| By feature | Import/, Transcription/, Foundation/, Settings/, Shared/. | :white_check_mark: |
| By layer | Models/, Views/, Services/, Helpers/. Traditional MVC. | |
| You decide | Claude picks based on app complexity. | |

**User's choice:** By feature
**Notes:** User also requested carufus_whozit (../carufus_whozit) be used as primary reference for organization, patterns, and UI/UX quality. Sezit for modern OpenAI classes and settings/first screens patterns.

---

## Content Import UX

### Entry point for importing content?

| Option | Description | Selected |
|--------|-------------|----------|
| Content library screen | Home screen shows library. '+' to add. Type icon, title, duration per item. | :white_check_mark: |
| Direct to session | No library, pick content each time. | |
| Tab-based like whozit | Tabs for content types: Videos, Audio, Text. | |

**User's choice:** Content library screen
**Notes:** None

### Which picker for import?

| Option | Description | Selected |
|--------|-------------|----------|
| PhotosPicker for video, Files for audio | Each content type uses native picker. | :white_check_mark: |
| Single unified picker | DocumentPicker for everything. | |
| You decide | Claude picks. | |

**User's choice:** PhotosPicker for video, Files for audio
**Notes:** None

### '+' add content flow?

| Option | Description | Selected |
|--------|-------------|----------|
| Action sheet with 3 options | Import Video, Import Audio, Type Script. | :white_check_mark: |
| Bottom menu/tab | Segmented control: Video, Audio, Text. | |
| You decide | Claude picks. | |

**User's choice:** Action sheet with 3 options
**Notes:** None

### How should imported content be previewed?

| Option | Description | Selected |
|--------|-------------|----------|
| Inline preview in library | Tap for detail: video player, audio play, text preview. 'Start Practice' button. | :white_check_mark: |
| Full-screen preview | Full-screen playback/reading view. | |
| You decide | Claude picks. | |

**User's choice:** Inline preview in library
**Notes:** None

---

## Transcription Workflow

### When should transcription be triggered?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual button on content detail | 'Transcribe' button. User explicitly requests. | :white_check_mark: |
| Auto after import | Automatically transcribe every import. | |
| Prompt after import | Ask 'Would you like to transcribe?' | |

**User's choice:** Manual button on content detail
**Notes:** None

### How should progress be shown?

| Option | Description | Selected |
|--------|-------------|----------|
| Inline progress on detail screen | Button becomes progress indicator. Transcript appears in place. | :white_check_mark: |
| Modal sheet with progress | Full sheet with upload/processing status. | |
| You decide | Claude picks. | |

**User's choice:** Inline progress on detail screen
**Notes:** None

### Whisper vs Apple Speech fallback?

| Option | Description | Selected |
|--------|-------------|----------|
| Silent fallback like whozit | Falls back to Apple Speech silently. Shows method used after. | :white_check_mark: |
| Explicit choice | User chooses Whisper vs on-device. | |
| Try Whisper, offer retry | If Whisper fails, offer on-device retry. | |

**User's choice:** Selected silent fallback but added note: "let's just use whisper for now and don't fa[ll back]"
**Notes:** Whisper only for Phase 1. No Apple Speech fallback. TRANS-04 deferred.

### Audio preprocessing?

| Option | Description | Selected |
|--------|-------------|----------|
| Transparent, always on | Always preprocess. Saves costs, improves accuracy. | :white_check_mark: |
| User toggle | Settings toggle, default on. | |
| You decide | Claude picks. | |

**User's choice:** Transparent, always on
**Notes:** None

---

## API Key Setup Flow

### When to ask for API key?

| Option | Description | Selected |
|--------|-------------|----------|
| On first transcription attempt | Lazy prompt when user first taps Transcribe. | :white_check_mark: |
| Onboarding flow like sezit | Step-by-step onboarding on first launch. | |
| Settings only | Entry in Settings, user discovers it. | |

**User's choice:** On first transcription attempt
**Notes:** None

### API key entry screen design?

| Option | Description | Selected |
|--------|-------------|----------|
| Like carufus_whozit Settings | SecureField + eye toggle + Save + checkmark. Proven pattern. | :white_check_mark: |
| Dedicated setup sheet | Modal with instructions and link. | |
| You decide | Claude picks. | |

**User's choice:** Like carufus_whozit Settings
**Notes:** None

---

## Claude's Discretion

- SwiftData model schema design
- File storage structure within app sandbox
- Network monitoring approach
- Theme/color choices

## Deferred Ideas

- TRANS-04 (SFSpeechRecognizer fallback) — deferred from Phase 1, Whisper only
- Onboarding flow — not needed since API key is lazy-prompted
