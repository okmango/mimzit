import SwiftUI
import SwiftData

/// Session history list with optional content filter.
///
/// ## Filter Pattern
/// Uses a two-subview pattern for dynamic @Query predicates (Pattern 7 from research).
/// `FilteredSessionList` and `AllSessionsList` are separate structs so SwiftData can
/// compile the @Query predicate at init time with a concrete UUID value.
///
/// ## Bidirectional Navigation
/// - Content -> Sessions (D-10): ContentDetailView links here with contentFilter
/// - Sessions -> Content (D-11): Context menu on each row opens ContentDetailView sheet
///
/// ## Deletion
/// Swipe-to-delete calls FileVault.deleteSession FIRST (file removal), then
/// modelContext.delete (SwiftData record removal) per Pitfall 1 from research.
struct SessionHistoryView: View {
    let contentFilter: UUID?

    init(contentFilter: UUID? = nil) {
        self.contentFilter = contentFilter
    }

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

// MARK: - Shared List Body Helper

/// Shared content view used by both AllSessionsList and FilteredSessionList.
///
/// Accepts bindings to keep state in the parent (session-specific) views that own @Query.
private struct SessionListContent: View {
    @Environment(\.modelContext) private var modelContext
    let sessions: [Session]
    @Binding var sessionToDelete: Session?
    @Binding var showDeleteConfirmation: Bool
    @Binding var selectedContentForSheet: ReferenceContent?

    /// Thumbnail lookup: maps ReferenceContent.id -> thumbnailFilename for fast row rendering.
    let thumbnailMap: [UUID: String?]

    var body: some View {
        Group {
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No sessions yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink(destination: ReviewView(session: session)) {
                            SessionRowView(
                                session: session,
                                thumbnailFilename: thumbnailMap[session.referenceContentID] ?? nil
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                sessionToDelete = session
                                showDeleteConfirmation = true
                            }
                        }
                        .contextMenu {
                            Button {
                                let id = session.referenceContentID
                                let descriptor = FetchDescriptor<ReferenceContent>(
                                    predicate: #Predicate { $0.id == id }
                                )
                                selectedContentForSheet = try? modelContext.fetch(descriptor).first
                            } label: {
                                Label("View Reference Content", systemImage: "film")
                            }
                        }
                    }
                }
            }
        }
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
                sessionToDelete = nil
            }
        } message: {
            Text("This will permanently remove the recording from your device.")
        }
        .sheet(item: $selectedContentForSheet) { content in
            ContentDetailView(content: content)
        }
    }

    private func deleteSession(_ session: Session) {
        // Delete the file from disk FIRST (per Pitfall 1 — SwiftData record must outlive file op)
        try? FileVault.deleteSession(filename: session.recordingFilename)
        modelContext.delete(session)
    }
}

// MARK: - All Sessions List

/// Shows all sessions sorted newest first.
struct AllSessionsList: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.recordedAt, order: .reverse) private var sessions: [Session]
    @Query private var allContent: [ReferenceContent]

    @State private var sessionToDelete: Session?
    @State private var showDeleteConfirmation = false
    @State private var selectedContentForSheet: ReferenceContent?

    var body: some View {
        SessionListContent(
            sessions: sessions,
            sessionToDelete: $sessionToDelete,
            showDeleteConfirmation: $showDeleteConfirmation,
            selectedContentForSheet: $selectedContentForSheet,
            thumbnailMap: buildThumbnailMap(from: allContent)
        )
    }

    private func buildThumbnailMap(from content: [ReferenceContent]) -> [UUID: String?] {
        Dictionary(uniqueKeysWithValues: content.map { ($0.id, $0.thumbnailFilename) })
    }
}

// MARK: - Filtered Session List

/// Shows sessions filtered by a specific ReferenceContent ID, sorted newest first.
struct FilteredSessionList: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]
    @Query private var allContent: [ReferenceContent]

    @State private var sessionToDelete: Session?
    @State private var showDeleteConfirmation = false
    @State private var selectedContentForSheet: ReferenceContent?

    init(contentID: UUID) {
        _sessions = Query(
            filter: #Predicate<Session> { $0.referenceContentID == contentID },
            sort: \Session.recordedAt,
            order: .reverse
        )
    }

    var body: some View {
        SessionListContent(
            sessions: sessions,
            sessionToDelete: $sessionToDelete,
            showDeleteConfirmation: $showDeleteConfirmation,
            selectedContentForSheet: $selectedContentForSheet,
            thumbnailMap: buildThumbnailMap(from: allContent)
        )
    }

    private func buildThumbnailMap(from content: [ReferenceContent]) -> [UUID: String?] {
        Dictionary(uniqueKeysWithValues: content.map { ($0.id, $0.thumbnailFilename) })
    }
}
