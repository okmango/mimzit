import SwiftUI

/// Custom horizontal fader (slider) with drag gesture, haptic snap points, and anchor labels.
///
/// ## Design
/// Pure SwiftUI `GeometryReader` + `DragGesture` — no UIViewRepresentable needed.
/// Track height is configurable: 8px for the video fader, 4px for the audio fader (UI-SPEC).
/// The thumb is a 28px circle centered on the track with a 44px minimum touch target.
///
/// ## Haptics
/// `UIImpactFeedbackGenerator(style: .light)` fires when the fader value crosses within ±0.02
/// of the snap points 0.0, 0.5, and 1.0. Each point fires only once per pass (edge-trigger).
///
/// ## Usage
/// ```swift
/// FaderView(
///     value: $videoBlend,
///     trackHeight: 8,
///     leftLabel: "REF",
///     rightLabel: "CAM"
/// )
/// ```
struct FaderView: View {

    // MARK: - Parameters

    /// Fader position: 0.0 (left/reference) to 1.0 (right/camera or mic).
    @Binding var value: Float

    /// Track height in points. Video fader uses 8pt; audio fader uses 4pt (UI-SPEC).
    let trackHeight: CGFloat

    /// Left anchor label (e.g. "REF"). 11pt Caption, `Theme.dimmedText`.
    let leftLabel: String

    /// Right anchor label (e.g. "CAM", "MIC", or "TEXT"). 11pt Caption, `Theme.dimmedText`.
    let rightLabel: String

    // MARK: - State

    @State private var isDragging = false

    /// Tracks which snap points have already fired a haptic during the current drag pass.
    @State private var firedSnapPoints: Set<Float> = []

    // MARK: - Constants

    private let thumbDiameter: CGFloat = 28
    private let snapPoints: [Float] = [0.0, 0.5, 1.0]
    private let snapTolerance: Float = 0.02

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let thumbOffset = CGFloat(value) * (trackWidth - thumbDiameter)

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Theme.faderTrack)
                    .frame(height: trackHeight)

                // Filled track (left edge to thumb center)
                Capsule()
                    .fill(Theme.faderFilled)
                    .frame(
                        width: max(0, CGFloat(value) * trackWidth),
                        height: trackHeight
                    )

                // Thumb circle
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.30), radius: 4, y: 2)
                    .offset(x: thumbOffset)
            }
            .frame(height: 44) // 44pt minimum touch target (Apple HIG)
            .contentShape(Rectangle()) // Make full 44pt area tappable
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            firedSnapPoints = []
                        }
                        let newValue = Float(drag.location.x / trackWidth).clamped(to: 0...1)
                        triggerHapticsIfNeeded(oldValue: value, newValue: newValue)
                        value = newValue
                    }
                    .onEnded { _ in
                        isDragging = false
                        firedSnapPoints = []
                    }
            )
            .overlay(alignment: .bottomLeading) {
                Text(leftLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dimmedText)
                    .offset(y: 12)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(rightLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dimmedText)
                    .offset(y: 12)
            }
        }
        .frame(height: 44)
    }

    // MARK: - Haptics

    /// Fires a light haptic impact when `newValue` crosses within `snapTolerance` of a snap point
    /// and the previous value was outside that tolerance (edge-trigger, not level-trigger).
    private func triggerHapticsIfNeeded(oldValue: Float, newValue: Float) {
        for snap in snapPoints {
            let wasNear = abs(oldValue - snap) <= snapTolerance
            let isNear = abs(newValue - snap) <= snapTolerance
            if isNear && !wasNear && !firedSnapPoints.contains(snap) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                firedSnapPoints.insert(snap)
            }
        }
    }
}

// MARK: - Float Extension

private extension Float {
    /// Clamps the value to the given closed range.
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
