import SwiftUI

/// Pill-shaped segmented control for the four recording view modes.
///
/// ## Design (UI-SPEC ViewModeControl)
/// Four segments (Ref | Cam | Blend | Text) inside a single pill-shaped container.
/// The selected segment is highlighted with a `Theme.accent` filled capsule.
/// Unselected segments show `Theme.dimmedText` at 13pt Regular.
///
/// ## Text Segment Availability (VIEW-03)
/// The "Text" segment is disabled and visually dimmed (opacity 0.35) when `hasTranscript`
/// is false — no tap response, no tooltip needed. The segment reactivates immediately
/// when a transcript becomes available.
///
/// ## Interaction
/// Segment tap switches the mode with a 200ms easeInOut animation (UI-SPEC interaction contract).
///
/// ## Usage
/// ```swift
/// ViewModeControl(selected: $viewMode, hasTranscript: content.transcript != nil)
/// ```
struct ViewModeControl: View {

    // MARK: - Parameters

    /// The currently selected view mode, mirrored to/from the parent.
    @Binding var selected: ViewMode

    /// When false, the "Text" segment is dimmed and non-interactive (VIEW-03).
    let hasTranscript: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                segmentButton(for: mode)
            }
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .background(Theme.controlBg)
        .clipShape(Capsule())
    }

    // MARK: - Segment Button

    @ViewBuilder
    private func segmentButton(for mode: ViewMode) -> some View {
        let isSelected = selected == mode
        let isTextMode = mode == .textOverlay
        let isDisabled = isTextMode && !hasTranscript

        Button {
            withAnimation(.easeInOut(duration: 0.20)) {
                selected = mode
            }
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Theme.dimmedText)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Theme.accent)
                    }
                }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1.0)
    }
}
