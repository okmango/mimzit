import SwiftUI

/// Empty state view displayed in ContentLibraryView when no reference content has been imported.
///
/// Per UI-SPEC Screen 1 empty state:
/// - Icon: `film.stack` at 56 pt, `.secondary` foreground
/// - Heading: `.headline`, `.primary`
/// - Body: `.body`, `.secondary`, centered
struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No reference content yet")
                .font(.headline)
            Text("Tap + to import a video, audio file, or type a script.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    EmptyLibraryView()
}
