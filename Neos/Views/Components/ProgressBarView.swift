import SwiftUI

struct ProgressBarView: View {
    let playbackPosition: Int
    let playbackDuration: Int
    let lastProgressUpdate: Date
    let isPlaying: Bool
    let nowPlayingMID: String?
    var onSeek: ((TimeInterval) -> Void)?
    var showTrack: Bool = true
    var showTimeLabels: Bool = true
    var inlineTimeLabels: Bool = false

    private var isSeekable: Bool { onSeek != nil && playbackDuration > 0 }

    var body: some View {
        Group {
            if isSeekable, let onSeek {
                SeekerPerformanceIsland(
                    playbackPosition: playbackPosition,
                    playbackDuration: playbackDuration,
                    lastProgressUpdate: lastProgressUpdate,
                    isPlaying: isPlaying,
                    nowPlayingMID: nowPlayingMID,
                    onSeek: onSeek,
                    showTrack: showTrack,
                    showTimeLabels: showTimeLabels,
                    inlineTimeLabels: inlineTimeLabels
                )
            } else {
                staticBar
            }
        }
        .accessibilityIdentifier(AccessibilityID.Player.progressBar)
    }

    // MARK: - Static Bar (non-seekable)

    private var staticBar: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let barHeight: CGFloat = 3
                let yOffset = (size.height - barHeight) / 2
                let cornerRadius = barHeight / 2

                if showTrack {
                    var trackPath = Path()
                    trackPath.addRoundedRect(
                        in: CGRect(x: 0, y: yOffset, width: size.width, height: barHeight),
                        cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                    )
                    context.fill(trackPath, with: .color(Color.white.opacity(0.12)))
                }

                var fillPath = Path()
                fillPath.addRoundedRect(
                    in: CGRect(x: 0, y: yOffset, width: size.width * clamp(progressPercent), height: barHeight),
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )
                context.fill(fillPath, with: .color(DS.Colors.accent))
            }
        }
        .frame(height: 16)
    }

    private var progressPercent: Double {
        guard playbackDuration > 0 else { return 0 }
        return Double(playbackPosition) / Double(playbackDuration)
    }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}

// MARK: - Performance Island

/// Isolated view accepting only value types. The TimelineView lives here so
/// AppState mutations outside playback fields never trigger a re-render.
private struct SeekerPerformanceIsland: View {
    let playbackPosition: Int
    let playbackDuration: Int
    let lastProgressUpdate: Date
    let isPlaying: Bool
    let nowPlayingMID: String?
    let onSeek: (TimeInterval) -> Void
    let showTrack: Bool
    let showTimeLabels: Bool
    let inlineTimeLabels: Bool

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragProgress: Double?
    @State private var pendingSeekProgress: Double?
    @State private var lastSeekDate: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !isPlaying && dragProgress == nil)) { context in
            seekableLayout(at: context.date)
        }
        .onChange(of: playbackPosition) { _, newValue in
            handleServerUpdate(newValue)
        }
        .onChange(of: nowPlayingMID) { _, _ in
            pendingSeekProgress = nil
            lastSeekDate = nil
        }
    }

    // MARK: - Server Update Lockout

    private func handleServerUpdate(_ newPos: Int) {
        guard let seekDate = lastSeekDate else { return }
        let elapsed = Date().timeIntervalSince(seekDate)
        if elapsed > 2.0 || (elapsed > 0.5 && newPos > 0) {
            pendingSeekProgress = nil
            lastSeekDate = nil
        }
    }

    // MARK: - Display Progress

    private func displayProgress(at date: Date) -> Double {
        if let drag = dragProgress { return drag }
        if let pending = pendingSeekProgress { return pending }
        return clamp(interpolatedProgressPercent(at: date))
    }

    private func interpolatedProgressPercent(at now: Date) -> Double {
        guard playbackDuration > 0 else { return 0 }
        return Double(interpolatedPosition(at: now)) / Double(playbackDuration)
    }

    private func interpolatedPosition(at now: Date) -> Int {
        guard isPlaying else { return playbackPosition }
        let elapsed = now.timeIntervalSince(lastProgressUpdate)
        guard elapsed > 0 else { return playbackPosition }
        let interpolated = playbackPosition + Int(elapsed * 1000)
        return min(interpolated, playbackDuration)
    }

    // MARK: - Seekable Layout

    @ViewBuilder
    private func seekableLayout(at date: Date) -> some View {
        let progress = displayProgress(at: date)
        let currentMillis = Int(progress * Double(playbackDuration))

        if inlineTimeLabels && showTimeLabels {
            HStack(spacing: DS.Spacing.sm) {
                elapsedLabel(currentMillis).frame(width: 44, alignment: .trailing)
                seekBar(progress: progress)
                remainingLabel(currentMillis).frame(width: 50, alignment: .leading)
            }
        } else {
            VStack(spacing: DS.Spacing.sm) {
                seekBar(progress: progress)
                if showTimeLabels {
                    HStack {
                        elapsedLabel(currentMillis)
                        Spacer()
                        remainingLabel(currentMillis)
                    }
                    .typography(.badge)
                    .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Seek Bar

    @ViewBuilder
    private func seekBar(progress: Double) -> some View {
        GeometryReader { geo in
            CanvasSeekBar(
                progress: clamp(progress),
                isDragging: isDragging,
                isHovering: isHovering,
                showTrack: showTrack
            )
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.easeOut(duration: 0.15)) { isDragging = true }
                        }
                        dragProgress = clamp(value.location.x / geo.size.width)
                    }
                    .onEnded { value in
                        let finalProgress = clamp(value.location.x / geo.size.width)
                        let seekTime = finalProgress * Double(playbackDuration) / 1000.0
                        lastSeekDate = Date()
                        pendingSeekProgress = finalProgress
                        onSeek(seekTime)
                        withAnimation(.easeOut(duration: 0.15)) {
                            isDragging = false
                            dragProgress = nil
                        }
                    }
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
            }
        }
        .frame(height: 16)
        .drawingGroup()
        .accessibilityLabel("Playback position")
        .accessibilityValue(formatTime(Int(clamp(progress) * Double(playbackDuration))))
    }

    // MARK: - Time Labels

    @ViewBuilder
    private func elapsedLabel(_ millis: Int) -> some View {
        Text(formatTime(millis))
            .typography(.badge)
            .foregroundStyle(DS.Colors.textSecondary)
            .monospacedDigit()
    }

    @ViewBuilder
    private func remainingLabel(_ millis: Int) -> some View {
        Text("-\(formatTime(max(0, playbackDuration - millis)))")
            .typography(.badge)
            .foregroundStyle(DS.Colors.textSecondary)
            .monospacedDigit()
    }

    // MARK: - Helpers

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private func formatTime(_ millis: Int) -> String {
        let totalSeconds = max(0, millis / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct CanvasSeekBar: View {
    let progress: Double
    let isDragging: Bool
    let isHovering: Bool
    let showTrack: Bool

    var body: some View {
        Canvas { context, size in
            let barHeight: CGFloat = isDragging ? 6 : (isHovering ? 4.8 : 4)
            let yOffset = (size.height - barHeight) / 2
            let cornerRadius = barHeight / 2

            if showTrack {
                var trackPath = Path()
                trackPath.addRoundedRect(
                    in: CGRect(x: 0, y: yOffset, width: size.width, height: barHeight),
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )
                context.fill(trackPath, with: .color(Color.white.opacity(0.12)))
            }

            let fillWidth = max(0, min(size.width, size.width * progress))
            var fillPath = Path()
            fillPath.addRoundedRect(
                in: CGRect(x: 0, y: yOffset, width: fillWidth, height: barHeight),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
            context.fill(fillPath, with: .color(DS.Colors.accent))

            if isHovering || isDragging {
                let knobSize: CGFloat = 12
                let knobX = min(max(0, (size.width * progress) - (knobSize / 2)), size.width - knobSize)
                let knobY = (size.height - knobSize) / 2

                var knobPath = Path()
                knobPath.addEllipse(in: CGRect(x: knobX, y: knobY, width: knobSize, height: knobSize))
                context.addFilter(.shadow(color: .black.opacity(0.2), radius: 2, y: 1))
                context.fill(knobPath, with: .color(DS.Colors.accent))
            }
        }
    }
}
