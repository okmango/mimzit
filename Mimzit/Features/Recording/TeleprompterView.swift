import SwiftUI

/// Auto-scrolling teleprompter with current-line highlight and speed control.
///
/// ## Two Rendering Modes
/// - **Full-screen (isFullScreen: true):** Black background, large text, speed slider visible.
///   Used for text-only content (D-13, D-14) or when the view mode is `.textOverlay`
///   and the content type is `.text`.
/// - **Overlay (isFullScreen: false):** Semi-transparent dark band at the bottom of the screen.
///   Used for transcript overlay on top of reference video (D-12, VIEW-02).
///
/// ## Auto-Scroll (D-13)
/// `Timer.publish` fires every 0.05s. When `isScrolling` is true, `currentLineIndex` advances
/// based on `scrollSpeed` (1x–4x multiplier). `ScrollViewReader.scrollTo(_:anchor:)` keeps
/// the current line centered. Scroll pauses instantly when `isScrolling` becomes false.
///
/// ## Current Line Highlight (D-14)
/// Current line: 28pt Semibold white with a 4px left accent bar (`Theme.accent`).
/// Other lines: 16pt Regular, `Theme.teleprompterDim` (50% white opacity).
///
/// ## Usage
/// ```swift
/// TeleprompterView(
///     text: content.transcript ?? "",
///     isScrolling: $isRecording,
///     scrollSpeed: $scrollSpeed,
///     isFullScreen: true
/// )
/// ```
struct TeleprompterView: View {

    // MARK: - Parameters

    /// The full transcript or script text to display.
    let text: String

    /// Driven by `RecordingViewModel.isRecording`. Scroll runs when true, pauses when false.
    @Binding var isScrolling: Bool

    /// Speed multiplier from 1.0 (slowest) to 4.0 (fastest). Default 1.0.
    @Binding var scrollSpeed: Double

    /// True for full-screen text-only mode (black bg, speed slider visible).
    /// False for text overlay mode (semi-transparent band, bottom-third of screen).
    let isFullScreen: Bool

    // MARK: - State

    @State private var currentLineIndex: Int = 0

    /// Accumulated fractional line index for smooth sub-line scroll advancement.
    @State private var fractionalIndex: Double = 0.0

    // MARK: - Computed

    /// Lines derived from the text. Non-empty lines only.
    private var lines: [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Body

    var body: some View {
        if isFullScreen {
            fullScreenTeleprompter
        } else {
            overlayTeleprompter
        }
    }

    // MARK: - Full-Screen Mode

    private var fullScreenTeleprompter: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                lineView(line: line, index: index, isOverlay: false)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 40)
                    }
                    .onReceive(
                        Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
                    ) { _ in
                        guard isScrolling, !lines.isEmpty else { return }
                        // Advance fractional index by speed-adjusted step
                        // scrollSpeed 1.0 = ~0.3 lines/sec; 4.0 = ~1.2 lines/sec
                        let step = scrollSpeed * 0.015
                        fractionalIndex += step
                        let newIndex = min(Int(fractionalIndex), lines.count - 1)
                        if newIndex != currentLineIndex {
                            currentLineIndex = newIndex
                            withAnimation(.linear(duration: 0.05)) {
                                proxy.scrollTo(currentLineIndex, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: text) { _, _ in
                        currentLineIndex = 0
                        fractionalIndex = 0.0
                    }
                    .onChange(of: isScrolling) { _, scrolling in
                        if !scrolling {
                            // Pause — nothing to do; timer guard handles it
                        } else {
                            // Resume from current position
                        }
                    }
                }

                // Speed control (full-screen mode only)
                speedControl
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Overlay Mode

    private var overlayTeleprompter: some View {
        ZStack {
            Theme.textOverlayBg
                .ignoresSafeArea(edges: .bottom)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            lineView(line: line, index: index, isOverlay: true)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onReceive(
                    Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
                ) { _ in
                    guard isScrolling, !lines.isEmpty else { return }
                    let step = scrollSpeed * 0.015
                    fractionalIndex += step
                    let newIndex = min(Int(fractionalIndex), lines.count - 1)
                    if newIndex != currentLineIndex {
                        currentLineIndex = newIndex
                        withAnimation(.linear(duration: 0.05)) {
                            proxy.scrollTo(currentLineIndex, anchor: .center)
                        }
                    }
                }
                .onChange(of: text) { _, _ in
                    currentLineIndex = 0
                    fractionalIndex = 0.0
                }
            }
        }
    }

    // MARK: - Line View

    @ViewBuilder
    private func lineView(line: String, index: Int, isOverlay: Bool) -> some View {
        let isCurrent = index == currentLineIndex

        if isCurrent {
            HStack(alignment: .top, spacing: 8) {
                // Left accent bar for current line (D-14)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 4)
                    .frame(minHeight: isOverlay ? 20 : 34)

                Text(line)
                    .font(.system(size: isOverlay ? 16 : 28, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(line)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Theme.teleprompterDim)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, isOverlay ? 0 : 12) // indent to align with accent bar
        }
    }

    // MARK: - Speed Control

    private var speedControl: some View {
        HStack {
            Text("Speed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.dimmedText)

            Slider(value: $scrollSpeed, in: 1...4, step: 0.5)
                .tint(Theme.accent)

            Text(String(format: "%.1fx", scrollSpeed))
                .font(.system(size: 13))
                .foregroundColor(Theme.dimmedText)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Theme.overlayPanel)
        .clipShape(Capsule())
    }
}
