# Phase 3: Sessions + Review - Research

**Researched:** 2026-03-26
**Domain:** SwiftData schema migration, dual-AVPlayer synchronized playback, session persistence, review UI composition
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Auto-save immediately when recording stops (user taps stop or reference video ends). No save/discard prompt. User can delete from history later.
- **D-02:** After auto-save, stay on the recording screen. A brief toast/banner confirms the save. User is ready to record another take immediately.
- **D-03:** Session data model stores: reference content link, recording filename (relative, via FileVault pattern), duration, syncTimestamp (from REC-05), recorded-at date.
- **D-04:** Review screen reuses the same layout as the recording screen (CompositorView + FaderView). Replace the record button with play/pause. Add a scrub bar (timeline slider). No camera preview — show reference video + user recording blended via fader.
- **D-05:** Fader labels change for review mode: video fader shows "REF" (left) / "YOU" (right). Audio fader shows "REF" / "YOU".
- **D-06:** View mode control in review: Ref | You | Blend (Text available only if transcript exists on the reference content).
- **D-07:** Audio fader works normally in review mode (controls reference volume blend, same as Phase 2 idle behavior).
- **D-08:** New "Sessions" tab added between Library and Settings in the main TabView. All sessions across all content, sorted newest first.
- **D-09:** Each session row: reference content title, date/time, duration, reference content thumbnail on left.
- **D-10:** Sessions tab supports filtering by content item. Content detail view has a "Sessions" link that navigates to Sessions tab with pre-applied filter.
- **D-11:** Bidirectional navigation: session row links to content detail; content detail links to filtered sessions.
- **D-12:** Chronological session list filtered by content IS the progress comparison mechanism. No separate comparison view.
- **D-13:** `syncTimestamp` (CACurrentMediaTime at recording start) persisted with session for review playback alignment.
- **D-14:** `lastRecordingURL` from RecordingViewModel provides the file to move into permanent storage.
- **D-15:** PlaybackEngine reused directly for review playback. CompositorView reused with two AVPlayerLayers instead of AVPlayerLayer + AVCaptureVideoPreviewLayer.

### Claude's Discretion

- SwiftData schema migration approach (V1 → V2 with Session model)
- Toast/banner animation and timing for save confirmation
- Scrub bar visual design and interaction details
- How to handle the CompositorView adaptation for two AVPlayerLayers (review mode)
- Session row layout specifics (font sizes, spacing, thumbnail size)
- Filter UI design in Sessions tab (chip, search bar, or segmented control)
- Whether to generate recording thumbnails or reuse reference thumbnails

### Deferred Ideas (OUT OF SCOPE)

- Side-by-side dual session comparison (pick two sessions, play simultaneously) — v2
- Recording preview thumbnails generated from user video — v2
- Session notes/annotations — v2 (ORG-02)
- Session renaming — v2 (ORG-01)
- Export to Camera Roll — v2 (EXP-01, EXP-02)

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SESS-01 | User can save a completed practice session (reference + user recording pair + metadata) | SwiftData Session model (V2 migration), FileVault `moveRecording` method, RecordingViewModel auto-save hook on `lastRecordingURL` change |
| SESS-02 | User can view a list of saved sessions sorted by date with timestamps | `@Query(sort: \Session.recordedAt, order: .reverse)` in SessionHistoryView, mirroring ContentLibraryView pattern |
| SESS-03 | User can delete saved sessions to free storage | Swipe-to-delete with confirmation alert; FileVault.delete for recording file; modelContext.delete for SwiftData record |
| SESS-04 | Session data persists across app launches (SwiftData, schema versioning) | MimzitSchemaV2 + MimzitMigrationPlan updated; ModelContainer updated to include Session.self |
| REV-01 | User can review any saved session with the same fader playback UI | ReviewView reuses CompositorView with two AVPlayerLayers; ReviewViewModel owns two PlaybackEngine instances; FaderView reused with REF/YOU labels |
| REV-02 | Reference video and user recording play back in sync (within acceptable drift) | Dual-player sync via addPeriodicTimeObserver on reference player + conditional seek on user player when drift exceeds 0.05s; syncTimestamp offset applied at load time |
| REV-03 | User can pause and scrub through review playback | PlaybackEngine.seek(to:) exposed via scrub bar; pause/play toggle button replaces record button in ReviewView |
| REV-04 | User can compare different sessions of the same reference video | SessionHistoryView filter by content (via content ID predicate); chronological list is the comparison mechanism |

</phase_requirements>

---

## Summary

Phase 3 builds on the complete Phase 2 codebase by adding three new capabilities: session persistence (SwiftData V2 migration + FileVault extension), a session history tab (SessionHistoryView mirroring ContentLibraryView), and a review screen (ReviewView + ReviewViewModel reusing CompositorView and PlaybackEngine). The fundamental challenge is dual-player synchronized playback — two AVPlayer instances must stay within one frame of each other during scrubbing and normal playback.

The codebase already has the full machinery needed. `RecordingViewModel.lastRecordingURL` is the save trigger. `FileVault` already has `recordingsDirectory` and `recordingURL(filename:)`. `CompositorView` already accepts an optional `previewLayer` parameter — in review mode this becomes a second `AVPlayerLayer`. `PlaybackEngine` already exposes `seek(to:)` and `pause()`. The main new logic is the `Session` SwiftData model, the V2 migration, the auto-save orchestration in `RecordingViewModel`, and the dual-player sync in `ReviewViewModel`.

**Primary recommendation:** Implement in three sequential steps — (1) Session model + FileVault extension + auto-save wired into RecordingViewModel, (2) SessionHistoryView + SessionsTab + content detail link, (3) ReviewView + ReviewViewModel with dual-player sync. Do not attempt all three in one plan wave.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ | Session metadata persistence | Already in use for ReferenceContent; @Query drives SessionHistoryView |
| AVFoundation (AVPlayer) | iOS 16+ | Dual-player review playback | PlaybackEngine already wraps AVPlayer; two instances for reference + user recording |
| FileManager | iOS 16+ | Move recording from temp to permanent session storage | FileVault already owns all file I/O; extend with session-scoped move |
| SwiftUI | iOS 16+ | SessionHistoryView, ReviewView, toast overlay | All non-video UI |
| CALayer opacity | iOS 16+ | Video blend in ReviewCompositorView | Same GPU-composited approach as recording screen |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVKit VideoPlayer | iOS 16+ | Thumbnail preview in session rows | Use ONLY for thumbnail still frame — do not use for review screen |
| AVAssetImageGenerator | iOS 16+ | Generate reference content thumbnail for session row | Already used in ContentLibraryView.generateThumbnail; reuse same pattern |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Two separate AVPlayer instances for review sync | AVMutableComposition single player | AVMutableComposition overhead for in-app review; two AVPlayers + periodic sync is simpler and has no offline rendering cost |
| Periodic time observer for drift correction | AVSynchronizedLayer | AVSynchronizedLayer requires iOS 15+ and a parent-child layer relationship; periodic observer is simpler and sufficient for ±0.1s drift tolerance |
| Reference thumbnail reuse in session rows | Generate recording thumbnail | Recording thumbnail generation deferred to v2 per CONTEXT.md; reuse reference content thumbnailFilename |

---

## Architecture Patterns

### Recommended Project Structure (additions for Phase 3)

```
Mimzit/
├── Features/
│   ├── Sessions/
│   │   ├── SessionHistoryView.swift    # @Query list, filter by content
│   │   └── SessionRowView.swift        # thumbnail + title + date + duration
│   └── Review/
│       ├── ReviewView.swift            # CompositorView + FaderView + scrub bar
│       └── ReviewViewModel.swift       # two PlaybackEngines, sync logic
├── Models/
│   ├── Session.swift                   # SwiftData @Model (V2)
│   └── MimzitMigrationPlan.swift       # updated for V2 (existing file)
└── Services/
    └── FileVault.swift                 # extend with moveRecording(from:filename:)
```

### Pattern 1: SwiftData V2 Migration

**What:** Add `Session` model to a new `MimzitSchemaV2`. Update `MimzitMigrationPlan` to include V2 in schemas array. For a purely additive migration (new model, no column changes to V1), no migration stage is needed — SwiftData handles new model addition automatically.

**When to use:** Any time a new SwiftData model is introduced in a new phase.

**Example:**
```swift
// MimzitSchemaV2 — new file alongside MimzitMigrationPlan.swift
enum MimzitSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ReferenceContent.self, Session.self]
    }
}

// MimzitMigrationPlan — update schemas + add lightweight stage
enum MimzitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] {
        [MimzitSchemaV1.self, MimzitSchemaV2.self]
    }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: MimzitSchemaV1.self, toVersion: MimzitSchemaV2.self)]
    }
}
```

**ModelContainer update in MimzitApp:**
```swift
// MimzitApp.swift — add Session.self to container
.modelContainer(for: [ReferenceContent.self, Session.self], migrationPlan: MimzitMigrationPlan.self)
```

**Confidence:** HIGH — additive migrations are explicitly documented as lightweight in SwiftData docs.

### Pattern 2: Session SwiftData Model

**What:** `Session` stores only metadata and relative filenames. No binary data in SwiftData. Relationships use a stored UUID rather than a SwiftData `@Relationship` to avoid cascade-delete complexity.

**When to use:** This is the correct pattern for this app — ReferenceContent already uses the same approach.

**Example:**
```swift
@Model
final class Session {
    var id: UUID
    var recordedAt: Date
    var duration: TimeInterval
    var syncTimestamp: Double          // CACurrentMediaTime at recording start (REC-05)

    /// Relative filename in Documents/sessions/ — resolved by FileVault.sessionURL(for:)
    var recordingFilename: String

    /// Reference to parent ReferenceContent — stored as UUID (not @Relationship)
    /// to avoid SwiftData cascade-delete complexity.
    var referenceContentID: UUID
    var referenceContentTitle: String  // denormalized for display without join

    init(
        recordedAt: Date = Date(),
        duration: TimeInterval,
        syncTimestamp: Double,
        recordingFilename: String,
        referenceContentID: UUID,
        referenceContentTitle: String
    ) {
        self.id = UUID()
        self.recordedAt = recordedAt
        self.duration = duration
        self.syncTimestamp = syncTimestamp
        self.recordingFilename = recordingFilename
        self.referenceContentID = referenceContentID
        self.referenceContentTitle = referenceContentTitle
    }
}
```

**Why denormalize title:** `@Query` on Session cannot join ReferenceContent. Denormalizing the title avoids fetching ReferenceContent for every session row. Title is display-only and stable after creation.

**Why UUID not @Relationship:** SwiftData `@Relationship` with cascade delete would delete sessions when content is deleted (wrong behavior — sessions are independent). Storing UUID allows session list to survive content deletion (session row shows "Deleted Content" fallback).

**Confidence:** HIGH — based on ReferenceContent pattern already in codebase and SwiftData cascade behavior.

### Pattern 3: FileVault Extension for Session Storage

**What:** Recordings permanently stored in `Documents/sessions/` after auto-save. `Documents/recordings/` remains temp-only. FileVault gets `moveRecording(from:toSessionFilename:)` and `sessionURL(for:)`.

**When to use:** Auto-save trigger in RecordingViewModel.

**Example:**
```swift
// FileVault extension additions
extension FileVault {
    static var sessionsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sessions", isDirectory: true)
    }

    /// Moves a completed recording from the temp recordings/ dir to permanent sessions/ dir.
    /// Returns the relative filename stored in Session.recordingFilename.
    static func moveRecording(from tempURL: URL, filename: String) throws -> String {
        try FileManager.default.createDirectory(
            at: sessionsDirectory,
            withIntermediateDirectories: true
        )
        let destination = sessionsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return filename
    }

    static func sessionURL(for filename: String) -> URL {
        sessionsDirectory.appendingPathComponent(filename)
    }

    static func deleteSession(filename: String) throws {
        let fileURL = sessionsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
```

**Confidence:** HIGH — mirrors existing FileVault pattern exactly.

### Pattern 4: Auto-Save in RecordingViewModel

**What:** Auto-save triggers on `lastRecordingURL` assignment. `RecordingViewModel` needs a `modelContext` reference injected to insert a `Session`. Use `.onChange(of: viewModel.lastRecordingURL)` in RecordingView to trigger save — keeping the view model free of SwiftData context injection.

**Two approaches evaluated:**

**Option A (recommended): onChange in RecordingView**
```swift
// RecordingView.swift
@Environment(\.modelContext) private var modelContext

.onChange(of: viewModel.lastRecordingURL) { _, newURL in
    guard let url = newURL else { return }
    Task { await saveSession(recordingURL: url) }
}

private func saveSession(recordingURL: URL) async {
    let filename = "\(UUID().uuidString).mov"
    guard let stored = try? FileVault.moveRecording(from: recordingURL, filename: filename) else { return }
    let session = Session(
        duration: viewModel.recordingDuration,
        syncTimestamp: viewModel.syncTimestamp,
        recordingFilename: stored,
        referenceContentID: content.id,
        referenceContentTitle: content.title
    )
    modelContext.insert(session)
    viewModel.showSaveConfirmation()
}
```

**Option B: Pass modelContext into RecordingViewModel**
Requires making RecordingViewModel aware of SwiftData — violates the existing pattern where RecordingViewModel knows nothing about persistence. Option A is preferred.

**Why onChange:** `lastRecordingURL` is set in the AVCaptureFileOutputRecordingDelegate callback, which is already dispatched to @MainActor. The onChange fires reliably on the main actor.

**Confidence:** HIGH — onChange(of:) pattern is standard SwiftUI for reacting to @Observable state changes.

### Pattern 5: Dual-Player Sync in ReviewViewModel

**What:** Two PlaybackEngine instances driven by a periodic time observer on the reference player. When reference player time advances, compare to user recording player time. If drift exceeds threshold (0.05s), seek user player to match.

**When to use:** Review playback only — not recording screen.

**Example:**
```swift
@Observable
@MainActor
final class ReviewViewModel {
    let session: Session
    let referenceContent: ReferenceContent

    let referenceEngine = PlaybackEngine()   // bottom layer (reference)
    let userEngine = PlaybackEngine()        // top layer (user recording)

    var videoBlend: Float = 0.5
    var audioBlend: Float = 0.0
    var activeViewMode: ViewMode = .blend
    var isPlaying = false
    var scrubPosition: Double = 0           // 0.0–1.0 normalized
    var duration: TimeInterval = 0

    private var syncObserver: Any?
    private let syncThreshold: Double = 0.05  // 50ms tolerance

    func setup() {
        let refURL = FileVault.url(for: referenceContent.filename ?? "")
        let userURL = FileVault.sessionURL(for: session.recordingFilename)
        referenceEngine.load(url: refURL)
        userEngine.load(url: userURL)
        duration = referenceContent.duration ?? 0
        setupSyncObserver()
    }

    private func setupSyncObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        syncObserver = referenceEngine.player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            // Update scrub bar position
            if self.duration > 0 {
                self.scrubPosition = time.seconds / self.duration
            }
            // Drift correction
            let refTime = time.seconds
            let userTime = self.userEngine.player.currentTime().seconds
            // Offset user time by syncTimestamp delta if needed
            let drift = abs(refTime - userTime)
            if drift > self.syncThreshold {
                self.userEngine.seek(to: CMTime(seconds: refTime, preferredTimescale: 600))
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            referenceEngine.pause()
            userEngine.pause()
            isPlaying = false
        } else {
            referenceEngine.play()
            userEngine.play()
            isPlaying = true
        }
    }

    func scrub(to normalizedPosition: Double) {
        let targetSeconds = normalizedPosition * duration
        let target = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        referenceEngine.seek(to: target)
        userEngine.seek(to: target)
    }

    func teardown() {
        if let obs = syncObserver {
            referenceEngine.player.removeTimeObserver(obs)
            syncObserver = nil
        }
        referenceEngine.pause()
        userEngine.pause()
    }
}
```

**syncTimestamp note:** The persisted `syncTimestamp` (CACurrentMediaTime) is a host-clock offset, not a media-time offset. Both recordings start at media time 0:00 — the syncTimestamp records when the host clock was at recording start. For review playback, both players seek to 0:00 simultaneously. The syncTimestamp is only needed if the reference video was not seeked to 0:00 at recording start (which RecordingViewModel does do via `playbackEngine.seek(to: .zero)`). For Phase 3, starting both players at 0:00 is the sync mechanism — syncTimestamp serves as a diagnostic/future-use field.

**Confidence:** HIGH — addPeriodicTimeObserver is the documented Apple pattern for time-based synchronization between two players.

### Pattern 6: CompositorView Adaptation for Two AVPlayerLayers

**What:** ReviewCompositorView (or adapted CompositorView) accepts two `AVPlayerLayer` parameters instead of `AVPlayerLayer + AVCaptureVideoPreviewLayer`. The second player layer takes the top slot previously occupied by `previewLayer`. Layer opacity logic is identical.

**Two options:**

**Option A (recommended): New ReviewCompositorView**
Create `ReviewCompositorView.swift` with `referencePlayerLayer` + `userPlayerLayer` parameters. Keeps recording-screen CompositorView unchanged. Clear naming distinction.

**Option B: Generalize CompositorView**
Replace `previewLayer: AVCaptureVideoPreviewLayer?` with `topLayer: CALayer?`. Both `AVCaptureVideoPreviewLayer` and `AVPlayerLayer` are `CALayer` subclasses. Reduces duplication but makes recording code less readable.

Recommendation: Option A for clarity. The types involved (AVCaptureVideoPreviewLayer vs AVPlayerLayer) differ in meaningful ways and having separate compositors makes intent explicit.

**ReviewCompositorView sketch:**
```swift
struct ReviewCompositorView: UIViewRepresentable {
    let referencePlayerLayer: AVPlayerLayer   // bottom — reference video
    let userPlayerLayer: AVPlayerLayer        // top — user recording
    let videoBlend: Float
    let activeViewMode: ViewMode

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        referencePlayerLayer.videoGravity = .resizeAspectFill
        userPlayerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(referencePlayerLayer)
        view.layer.addSublayer(userPlayerLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        referencePlayerLayer.frame = uiView.bounds
        userPlayerLayer.frame = uiView.bounds

        switch activeViewMode {
        case .reference:
            referencePlayerLayer.opacity = 1.0
            userPlayerLayer.opacity = 0.0
        case .camera:  // "You" mode in review context
            referencePlayerLayer.opacity = 0.0
            userPlayerLayer.opacity = 1.0
        case .blend:
            referencePlayerLayer.opacity = 1.0
            userPlayerLayer.opacity = videoBlend
        case .textOverlay:
            referencePlayerLayer.opacity = 1.0
            userPlayerLayer.opacity = 0.0
        }

        CATransaction.commit()
    }
}
```

**ViewMode adaptation:** In review context, `.camera` case means "user recording only". D-05 says fader labels show "REF"/"YOU". ViewMode.camera raw value "Cam" becomes "You" in the segment label — this can be handled by a `reviewSegmentLabel` computed property on ViewMode, or by passing a label override parameter to ViewModeControl.

**Confidence:** HIGH — directly follows established CALayer + UIViewRepresentable patterns from Phase 2.

### Pattern 7: SessionHistoryView with Content Filter

**What:** `@Query` with optional predicate filtering by `referenceContentID`. SwiftData `@Query` does not support dynamic predicates bound to `@State` variables directly in Swift 5.9–5.10 — the filter must be passed at init time.

**The correct approach:**
```swift
struct SessionHistoryView: View {
    // Called with nil for "all sessions", or a UUID for filtered view
    let contentFilter: UUID?

    var body: some View {
        if let id = contentFilter {
            FilteredSessionList(contentID: id)
        } else {
            AllSessionsList()
        }
    }
}

// Separate view so @Query init receives the predicate at view creation
struct FilteredSessionList: View {
    @Query private var sessions: [Session]

    init(contentID: UUID) {
        _sessions = Query(
            filter: #Predicate<Session> { $0.referenceContentID == contentID },
            sort: \Session.recordedAt,
            order: .reverse
        )
    }
    // ...
}

struct AllSessionsList: View {
    @Query(sort: \Session.recordedAt, order: .reverse) private var sessions: [Session]
    // ...
}
```

**Why two views:** SwiftData @Query predicate cannot be changed after the view is initialized. This is the documented workaround: conditionally show a filtered vs unfiltered subview, each with its own @Query.

**Confidence:** HIGH — this is the canonical SwiftData dynamic query pattern documented in WWDC 2023 session 10196.

### Pattern 8: Toast / Save Confirmation Banner

**What:** Brief overlay banner that appears after auto-save, auto-dismisses after ~2 seconds. Implemented with `withAnimation` + Task.sleep, using `.overlay` alignment: `.top` on RecordingView.

**Example:**
```swift
// RecordingViewModel
var showSavedBanner = false

func showSaveConfirmation() {
    withAnimation(.easeIn(duration: 0.2)) {
        showSavedBanner = true
    }
    Task {
        try? await Task.sleep(for: .seconds(2))
        withAnimation(.easeOut(duration: 0.3)) {
            showSavedBanner = false
        }
    }
}
```

**Confidence:** HIGH — standard iOS in-app notification pattern.

### Anti-Patterns to Avoid

- **Seeking both players simultaneously without async care:** `AVPlayer.seek(to:)` is async internally. Calling seek on both players back-to-back is fine — they will seek independently. Do not wait for completion of player A before seeking player B; this serializes seeks unnecessarily and causes visible lag.
- **Storing AVPlayer or AVPlayerLayer in SwiftData:** Never. Only store filenames.
- **Using @Relationship cascade delete on Session→ReferenceContent:** Deleting a content item should not cascade-delete sessions. Store referenceContentID as plain UUID.
- **Dynamic @Query predicate mutation:** Do not try to change a @Query predicate after view init. Use the two-subview pattern shown above.
- **Running FileManager.moveItem on main thread:** Move the recording file in a Task or background context. File I/O should not block the main thread, even for typical video sizes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dual-player time sync | Custom CADisplayLink poll + manual sync | `addPeriodicTimeObserver` on reference AVPlayer | AVPlayer's periodic observer fires on the correct CMTime; CADisplayLink fires on screen refresh regardless of media time |
| SwiftData dynamic filter | Custom NSPredicate string building | Two-subview @Query pattern | SwiftData #Predicate is type-safe and compile-checked; string predicates bypass type safety |
| Session file storage | Custom file path management | FileVault extension with `sessionsDirectory` | FileVault already handles path resolution, directory creation, and relative filename pattern |
| Review audio cross-fade | Custom AVAudioMix | `AVPlayer.volume` on both players inversely | Audio cross-fade for review is identical to Phase 2 idle behavior — `referenceEngine.volume = 1-x`, `userEngine.volume = x` |
| Toast animation | Custom UIKit overlay | SwiftUI `.overlay` + `withAnimation` | Pure SwiftUI is sufficient; no UIKit bridging needed |

**Key insight:** Phase 3 has almost zero new AVFoundation API surface. The entire implementation is orchestration of existing Phase 2 components plus SwiftData schema work. The risk is in the seams, not the new code.

---

## Common Pitfalls

### Pitfall 1: Session Deleted, Recording File Orphaned

**What goes wrong:** User deletes a session from SessionHistoryView. SwiftData record is deleted but `FileVault.deleteSession(filename:)` is never called. Disk fills up over time.

**Why it happens:** modelContext.delete only removes the SwiftData record. File I/O is separate.

**How to avoid:** Always call `FileVault.deleteSession(filename: session.recordingFilename)` BEFORE `modelContext.delete(session)`. Pattern directly mirrors `ContentLibraryView.deleteItem(_:)`.

**Warning signs:** Documents/sessions/ directory growing unbounded; storage reported incorrectly.

### Pitfall 2: Recording File Moved Before AVCaptureFileOutput Finishes

**What goes wrong:** Auto-save moves the temp recording file immediately on `toggleRecording()` call. But `lastRecordingURL` is only set in `fileOutput(_:didFinishRecordingTo:...)` — the delegate callback that fires AFTER the file is fully written. If save logic fires before the delegate callback, the file is incomplete or missing.

**Why it happens:** Confusion between `captureEngine.stopRecording()` call timing and delegate callback timing. Stop call is synchronous; delegate fires asynchronously after file finalization.

**How to avoid:** Trigger auto-save ONLY from `onChange(of: viewModel.lastRecordingURL)`. `lastRecordingURL` is set exclusively in the delegate callback, guaranteeing the file is finalized.

**Warning signs:** Saved sessions with 0 duration or empty file; AVPlayer fails to load session recording.

### Pitfall 3: Scrub Causes Audio Jump / Dual-Player Seeks Out of Order

**What goes wrong:** User drags scrub bar. Each drag position change calls `scrub(to:)` which calls seek on both players. Seeks arrive out-of-order — reference player is at T+0.5s, user player arrives at the pre-seek position briefly.

**Why it happens:** Both `AVPlayer.seek(to:)` calls are non-blocking. The second player seek may return before the first.

**How to avoid:** For scrubbing, accept this transient state — it lasts < 1 frame and the sync observer will correct drift within 100ms. Do not try to serialize seeks. For seek completion callbacks, use `seek(to:completionHandler:)` only if smoother scrub behavior is required (post-MVP).

**Warning signs:** Visible flicker of user recording layer during aggressive scrubbing.

### Pitfall 4: SwiftData Migration Fails Silently on Upgrade

**What goes wrong:** User has V1 database with only ReferenceContent. After upgrade, app runs with V2 model. If `MimzitMigrationPlan` is not updated correctly, SwiftData either fails silently (wipes database) or crashes.

**Why it happens:** SwiftData requires all versions to be listed in `schemas` array in chronological order. Missing a stage or misordering schemas causes migration failure.

**How to avoid:**
1. Add `MimzitSchemaV2.self` to schemas array AFTER `MimzitSchemaV1.self`
2. Add `.lightweight(fromVersion: MimzitSchemaV1.self, toVersion: MimzitSchemaV2.self)` to stages
3. Update ModelContainer to include `Session.self` in the models list
4. Test migration by building on simulator with existing V1 data before shipping

**Warning signs:** All content disappears after install; SwiftData container throws on launch.

### Pitfall 5: Content Detail View Sessions Filter Not Dismissed Correctly

**What goes wrong:** User taps "Sessions" link in ContentDetailView, which is presented as a `.sheet`. The link navigates to the Sessions tab with a filter. When user dismisses the sheet and then taps another content item, the Sessions tab still shows the previous filter.

**Why it happens:** Sessions tab filter state is `@State` in SessionHistoryView — it persists as long as the view stays in the tab hierarchy.

**How to avoid:** Use `@Binding` or a shared `@Observable` navigation model to drive the Sessions tab filter. When ContentDetailView sheet dismisses, clear the filter state. Alternatively, navigate to Sessions tab using a programmatic tab selection + pass filter as a navigation value (NavigationStack `navigationDestination`).

### Pitfall 6: syncTimestamp Misuse at Review Time

**What goes wrong:** Developer attempts to use `session.syncTimestamp` (a CACurrentMediaTime value) as a CMTime media offset for seeking. These are different clocks: `syncTimestamp` is the host clock (CACurrentMediaTime) when recording started; media time starts at 0:00 in both recordings.

**Why it happens:** syncTimestamp name implies it's used for sync. In practice, both videos start at media time 0:00 and the sync is achieved by playing both from 0:00 simultaneously.

**How to avoid:** In ReviewViewModel, always start both players at `.zero`. Do NOT use `syncTimestamp` as a seek offset. Store it for future diagnostics but do not use it as a CMTime value. Document this clearly in ReviewViewModel.

**Warning signs:** One video starts several seconds offset from the other during review.

---

## Code Examples

Verified patterns from existing codebase and established AVFoundation APIs:

### SwiftData @Query with Dynamic Filter (Two-Subview Pattern)
```swift
// Source: WWDC 2023 SwiftData session + existing ContentLibraryView pattern

struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let contentFilter: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if let id = contentFilter {
                    FilteredSessionList(contentID: id)
                } else {
                    AllSessionsList()
                }
            }
            .navigationTitle("Sessions")
        }
    }
}

struct AllSessionsList: View {
    @Query(sort: \Session.recordedAt, order: .reverse) private var sessions: [Session]
    // body: ForEach(sessions) { SessionRowView(...) }
}

struct FilteredSessionList: View {
    @Query private var sessions: [Session]

    init(contentID: UUID) {
        _sessions = Query(
            filter: #Predicate<Session> { session in
                session.referenceContentID == contentID
            },
            sort: \Session.recordedAt,
            order: .reverse
        )
    }
    // body: ForEach(sessions) { SessionRowView(...) }
}
```

### addPeriodicTimeObserver Dual-Sync Pattern
```swift
// Source: Apple AVFoundation AVPlayer documentation
let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
let observer = referencePlayer.addPeriodicTimeObserver(
    forInterval: interval,
    queue: .main
) { [weak self] time in
    guard let self else { return }
    let drift = abs(time.seconds - self.userPlayer.currentTime().seconds)
    if drift > 0.05 {
        self.userPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
// Store observer token; call removeTimeObserver(_:) in teardown
```

### Session Auto-Save in RecordingView
```swift
// onChange fires after AVCaptureFileOutputRecordingDelegate sets lastRecordingURL
.onChange(of: viewModel.lastRecordingURL) { _, newURL in
    guard let url = newURL else { return }
    Task { await saveSession(recordingURL: url) }
}

private func saveSession(recordingURL: URL) async {
    let filename = "\(UUID().uuidString).mov"
    guard let stored = try? FileVault.moveRecording(from: recordingURL, filename: filename) else {
        return
    }
    let session = Session(
        duration: viewModel.recordingDuration,
        syncTimestamp: viewModel.syncTimestamp,
        recordingFilename: stored,
        referenceContentID: content.id,
        referenceContentTitle: content.title
    )
    modelContext.insert(session)
    viewModel.showSaveConfirmation()
}
```

### Session Delete with File Cleanup
```swift
// Mirror of ContentLibraryView.deleteItem(_:)
private func deleteSession(_ session: Session) {
    try? FileVault.deleteSession(filename: session.recordingFilename)
    modelContext.delete(session)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CoreData for iOS persistence | SwiftData (iOS 17+) | iOS 17 / WWDC 2023 | @Query replaces NSFetchedResultsController; zero boilerplate for list views |
| Additive migration requires custom mapping | SwiftData lightweight migration for new models | iOS 17 | New model addition is `.lightweight` — no custom migration code |
| @FetchRequest with NSPredicate strings | SwiftData #Predicate macro (compile-time safe) | iOS 17 | Type-checked predicates; runtime errors become compile errors |
| AVSynchronizedLayer for dual-player sync | addPeriodicTimeObserver + manual seek | Always valid | AVSynchronizedLayer has constraints; periodic observer is simpler and sufficient |

---

## Open Questions

1. **Review audio cross-fade semantics**
   - What we know: D-07 says audio fader works "normally" in review mode, same as Phase 2 idle behavior (controls reference volume)
   - What's unclear: Whether user recording audio should be separately controllable via the audio fader, or if "REF / YOU" labels imply a true cross-fade (ref audio vs user recording audio)
   - Recommendation: Implement as true cross-fade in review: `referenceEngine.volume = 1 - audioBlend`, `userEngine.volume = audioBlend`. This is the natural interpretation of "REF / YOU" labels and provides useful comparison capability. If user recording has no audio (text-only practice), `userEngine.volume` will be 0 regardless.

2. **Sessions tab deep link from ContentDetailView**
   - What we know: D-10/D-11 require bidirectional navigation (content detail → filtered sessions tab)
   - What's unclear: ContentDetailView is presented as `.sheet`; navigating to a tab while a sheet is presented requires dismissing the sheet first, which adds state coordination
   - Recommendation: Add a "Sessions (N)" button to ContentDetailView that dismisses the sheet and sets a `@AppStorage` or environment-injected filter value that SessionHistoryView reads. Alternatively, present filtered sessions inline in ContentDetailView as a nested list (simpler, avoids cross-sheet tab navigation entirely). The inline approach is less elegant but avoids significant navigation state complexity. Recommend documenting this as a planning decision for the planner to resolve.

3. **RecordingViewModel modelContext access**
   - What we know: RecordingViewModel is `@Observable @MainActor` without any SwiftData dependency. D-14 says `lastRecordingURL` provides the save trigger.
   - What's unclear: Whether to inject modelContext into RecordingViewModel or keep save logic in RecordingView
   - Recommendation: Keep SwiftData concern in RecordingView via `@Environment(\.modelContext)` and `.onChange(of: viewModel.lastRecordingURL)`. This preserves the existing clean separation where the view model knows nothing about persistence.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 3 is purely code/config changes against the existing iOS project. No new external dependencies beyond the existing Xcode 16 + iOS simulator/device setup. All APIs (SwiftData, AVFoundation, FileManager) are part of the iOS SDK already integrated in the project.

---

## Project Constraints (from CLAUDE.md)

All CLAUDE.md directives that apply to Phase 3 planning:

| Directive | Applies To | Constraint |
|-----------|-----------|------------|
| SwiftData for session metadata | Session model | Binary video files MUST NOT go into SwiftData; store file paths only |
| FileManager Documents directory | FileVault extension | Use Documents/sessions/ subdirectory; never store absolute paths |
| AVKit VideoPlayer only for thumbnail previews | Session row thumbnail | Do NOT use VideoPlayer for review screen |
| Two separate AVPlayer instances for review | ReviewViewModel | Use two AVPlayer instances + seek-sync, NOT AVMutableComposition (which adds offline rendering overhead for in-app review) |
| SwiftUI @Observable @MainActor | ReviewViewModel | Follow established CaptureEngine/PlaybackEngine pattern |
| CALayer opacity for fader blend | ReviewCompositorView | GPU-composited; never AVMutableVideoComposition for live review |
| GSD workflow enforcement | All changes | All edits via `/gsd:execute-phase` — no direct repo edits |
| iOS 17+ minimum deployment | MimzitSchemaV2 | SwiftData migration APIs require iOS 17+ |
| No third-party video libraries | ReviewViewModel | AVFoundation only; no VLCKit or similar |

---

## Sources

### Primary (HIGH confidence)
- Existing codebase — `MimzitMigrationPlan.swift`, `ReferenceContent.swift`, `FileVault.swift`, `RecordingViewModel.swift`, `PlaybackEngine.swift`, `CompositorView.swift`, `ContentLibraryView.swift` — direct code inspection
- `CLAUDE.md` — stack decisions and constraints (project document)
- `.planning/research/ARCHITECTURE.md` — dual-player sync approach documented under "Review Playback Flow"
- `.planning/phases/03-sessions-review/03-CONTEXT.md` — locked decisions D-01 through D-15

### Secondary (MEDIUM confidence)
- Apple Developer Documentation — `addPeriodicTimeObserver(forInterval:queue:using:)` — periodic time observer pattern for dual-player sync
- WWDC 2023 Session 10196 "Model your schema with SwiftData" — dynamic @Query predicate two-subview pattern
- SwiftData SchemaMigrationPlan docs — lightweight migration for additive schema changes

### Tertiary (LOW confidence)
- None — all critical claims are grounded in codebase inspection or official documentation.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — same stack as Phases 1+2; no new external libraries
- Architecture: HIGH — patterns verified against existing codebase; dual-player sync is documented Apple API
- Pitfalls: HIGH — pitfalls 1, 2, 4 grounded in existing codebase structure; pitfalls 3, 5, 6 grounded in AVFoundation and SwiftData documented behavior

**Research date:** 2026-03-26
**Valid until:** 2026-09-01 (SwiftData and AVFoundation APIs are stable; SwiftData migration behavior changes are rare)
