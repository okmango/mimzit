# Phase 1: Foundation + Import + Transcription - Context

**Gathered:** 2026-03-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can import reference content (video from Camera Roll, audio from Files, typed text) into a persistent content library, preview it, and request AI transcription via OpenAI Whisper with audio preprocessing. App correctly configures AVAudioSession, stores API key in Keychain, and detects headphone status.

</domain>

<decisions>
## Implementation Decisions

### Xcode Project Structure
- **D-01:** Single-target app with XcodeGen (project.yml), consistent with sezit and carufus_whozit
- **D-02:** Feature-based folder organization: `Mimzit/Features/Import/`, `Mimzit/Features/Transcription/`, `Mimzit/Features/Settings/`, plus `Mimzit/App/`, `Mimzit/Models/`, `Mimzit/Services/`, `Mimzit/Shared/Components/`, `Mimzit/Resources/`
- **D-03:** Copy and adapt reusable code from sibling projects — no cross-project dependencies. Sources: KeychainService from carufus_whozit, AudioPreprocessor + WhisperAPIClient from sezit
- **D-04:** Use carufus_whozit as primary reference for organization, patterns, and UI/UX quality. Use sezit for OpenAI communication classes and settings/onboarding patterns

### Content Import UX
- **D-05:** Home screen is a content library showing all imported items. Each item shows type icon, title, duration. '+' button to add new content
- **D-06:** '+' button shows action sheet with 3 options: Import Video, Import Audio, Type Script
- **D-07:** SwiftUI PhotosPicker for video import (Camera Roll, mp4/mov). DocumentPicker for audio import (Files app, m4a/mp3). Inline text editor for script entry
- **D-08:** Tap content item to see inline detail/preview: video thumbnail with play, audio with play button, or text preview. 'Start Practice' button at bottom (wired in Phase 2)

### Transcription Workflow
- **D-09:** Manual transcription — 'Transcribe' button on content detail screen. User explicitly requests it
- **D-10:** Inline progress — button becomes progress indicator, transcript text appears in place when done. No modal, no navigation change
- **D-11:** Whisper API only for Phase 1 — no Apple Speech fallback. TRANS-04 (SFSpeechRecognizer fallback) is deferred to a later phase
- **D-12:** Audio preprocessing (silence removal + 1.5x speedup) always runs transparently before Whisper API call. Reuse sezit AudioPreprocessor pattern

### API Key Setup
- **D-13:** API key prompt triggered on first transcription attempt, not during onboarding. Users who import text-only content are never asked
- **D-14:** API key entry UI follows carufus_whozit SettingsView pattern: SecureField with eye toggle, Save button, checkmark when configured, stored in Keychain
- **D-15:** Settings screen includes API key management section (same as whozit pattern: configured state with checkmark + clear button, unconfigured state with entry field)

### Claude's Discretion
- Specific SwiftData model schema design (fields, relationships)
- File storage structure within app sandbox (Documents vs Application Support)
- Network monitoring approach for API availability
- Theme/color choices for the app

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Sibling Project Patterns (UI/UX + Organization)
- `../carufus_whozit/Whozit/` — Primary reference for folder organization, UI patterns, and UX quality (user's best app)
- `../carufus_whozit/Whozit/App/WhozitApp.swift` — App entry point, SwiftData ModelContainer setup, migration plan pattern
- `../carufus_whozit/Whozit/App/ContentView.swift` — Tab-based navigation, clean root view
- `../carufus_whozit/Whozit/Shared/Theme.swift` — Semantic color system with light/dark mode support
- `../carufus_whozit/Whozit/Features/Settings/SettingsView.swift` — API key entry, transcription settings, data management patterns
- `../carufus_whozit/Whozit/Services/KeychainService.swift` — Keychain wrapper to copy/adapt (enum-based, delete-then-add pattern)
- `../carufus_whozit/Whozit/Services/TranscriptionService.swift` — Whisper + Speech fallback, NetworkMonitor pattern
- `../carufus_whozit/Whozit/Models/SchemaVersion.swift` — Schema versioning pattern for SwiftData migrations

### Sibling Project Patterns (OpenAI + Audio)
- `../sezit/Sezit/Services/WhisperAPIClient.swift` — Whisper API communication (more modern OpenAI classes)
- `../sezit/Sezit/Services/AudioPreprocessor.swift` — Audio preprocessing: silence removal + speedup before Whisper
- `../sezit/Shared/KeychainHelper.swift` — Alternative Keychain pattern (prefer whozit's KeychainService)
- `../sezit/Sezit/Views/OnboardingView.swift` — Step-by-step onboarding with progress capsules (reference for future onboarding)
- `../sezit/Sezit/Views/SettingsView.swift` — Settings patterns

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — FOUND-01 through TRANS-04 requirement details
- `.planning/ROADMAP.md` — Phase 1 goal and success criteria
- `.planning/research/ARCHITECTURE.md` — AVFoundation architecture notes
- `.planning/research/STACK.md` — Technology stack decisions and rationale

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **KeychainService (whozit):** Enum-based Keychain wrapper with save/load/delete. Copy directly, change service identifier to `com.okmango.mimzit`
- **TranscriptionService (whozit):** Full Whisper + Speech fallback with NetworkMonitor. Adapt for Whisper-only, reuse network monitoring
- **AudioPreprocessor (sezit):** Silence removal + speedup. Copy and adapt for preprocessing before Whisper calls
- **WhisperAPIClient (sezit):** Modern OpenAI API communication. Adapt for mimzit's transcription needs

### Established Patterns
- **@MainActor + ObservableObject services:** Whozit uses `@MainActor final class ServiceName: ObservableObject` for all services
- **XcodeGen project.yml:** Both sezit and whozit use project.yml — mimzit should follow the same pattern
- **Features/ folder structure:** Whozit uses `Features/{FeatureName}/` with views + supporting files per feature
- **Shared/Components/:** Reusable UI components live in `Shared/Components/`
- **Models/ at root:** SwiftData models in top-level `Models/` folder, not nested in features
- **Services/ at root:** Business logic services in top-level `Services/` folder

### Integration Points
- **SwiftData ModelContainer:** Set up in App entry point following whozit's pattern with migration plan
- **AVAudioSession:** Configure in App init or didFinishLaunching before any media engine starts (FOUND-01, FOUND-02)
- **PhotosUI.PhotosPicker:** Native SwiftUI picker for video import (iOS 16+)
- **UIDocumentPickerViewController:** Wrapped in UIViewControllerRepresentable for audio file import from Files

</code_context>

<specifics>
## Specific Ideas

- carufus_whozit is the gold standard for UI/UX quality — match its polish level
- sezit has the more modern OpenAI communication classes — use those for Whisper integration
- sezit's onboarding pattern (step capsules + TabView paging) is good reference for any future onboarding but NOT needed in Phase 1 (API key is lazy-prompted)
- Content library should feel like a simple, clean list — not overwhelming for first-time users with zero content

</specifics>

<deferred>
## Deferred Ideas

- **TRANS-04 (SFSpeechRecognizer fallback):** Removed from Phase 1 scope per user decision. Whisper-only for now. Can be added as a future phase or folded into Phase 2/3
- **Onboarding flow:** Not needed in Phase 1 since API key is lazy-prompted. Reference sezit's OnboardingView if added later

</deferred>

---

*Phase: 01-foundation-import-transcription*
*Context gathered: 2026-03-25*
