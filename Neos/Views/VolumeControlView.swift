import SwiftUI
import NeosDomain

struct VolumeControlView: View {
    enum Style {
        case full      // MenuBar: mute button, flexible slider, dB label
        case compact   // Panel: dynamic icon, flexible slider, dB label
        case bottomBar // Main window bottom bar: icon + vertical popover
    }

    let state: AppState
    let viewModel: PlayerViewModel
    var style: Style = .full

    @State private var sliderVolume: Double = 0
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var showPopover = false
    @State private var dismissTask: Task<Void, Never>?
    @State private var panelState = VolumePanelState()

    private var effectiveMax: Double { Double(state.maxVolume ?? 100) }

    var body: some View {
        Group {
            switch style {
            case .full:
                fullLayout
            case .compact:
                compactLayout
            case .bottomBar:
                bottomBarLayout
            }
        }
        .onChange(of: sliderVolume) { _, newValue in
            if isDragging {
                viewModel.setVolume(Int(newValue))
            }
        }
        .onChange(of: state.volume) { _, newValue in
            if !isDragging {
                sliderVolume = Double(newValue)
            }
        }
        .onAppear {
            sliderVolume = Double(state.volume)
        }
    }

    // MARK: - Full Layout (MenuBar)

    private var fullLayout: some View {
        HStack(spacing: DS.Spacing.sm) {
            muteButton
            customSlider
            dBLabel
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Compact Layout (Panel)

    private var compactLayout: some View {
        HStack(spacing: DS.Spacing.sm) {
            muteButton
            customSlider
            dBLabel
        }
    }

    // MARK: - Bottom Bar Layout (AppKit hover zone + vertical popover)

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            if !isDragging && !(panelState.checkMouseInside?() ?? false) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showPopover = false
                }
            }
        }
    }

    private var bottomBarLayout: some View {
        muteButton
            .background {
                VolumeHoverZone(
                    isExpanded: showPopover,
                    panelState: panelState,
                    onHoverChanged: { hovering in
                        if hovering {
                            dismissTask?.cancel()
                            if !showPopover {
                                panelState.volume = sliderVolume
                                panelState.effectiveMax = effectiveMax
                                panelState.setVolume = { [viewModel] v in viewModel.setVolume(v) }
                                panelState.setAdjustingVolume = { [viewModel] a in viewModel.setAdjustingVolume(a) }
                                showPopover = true
                            }
                        } else if !panelState.isDragging {
                            scheduleDismiss()
                        }
                    }
                )
            }
            .onChange(of: panelState.isDragging) { _, newValue in
                isDragging = newValue
                if !newValue { scheduleDismiss() }
            }
            .onChange(of: panelState.volume) { _, newValue in
                sliderVolume = newValue
            }
            .onChange(of: state.volume) { _, newValue in
                if !panelState.isDragging {
                    panelState.volume = Double(newValue)
                }
            }
    }

    // MARK: - Shared Components

    @State private var isMuteHovered = false

    private var muteButton: some View {
        Button(action: { viewModel.toggleMute() }) {
            Image(systemName: volumeIcon)
                .font(style == .bottomBar ? DS.IconFont.xl : DS.IconFont.body)
                .foregroundStyle(state.isMuted ? .red : isMuteHovered ? .primary : DS.Colors.textSecondary)
                .frame(width: style == .bottomBar ? 28 : 20, height: style == .bottomBar ? 28 : 20)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isMuteHovered = hovering
            }
        }
        .help(state.isMuted ? "Unmute" : "Mute")
        .accessibilityIdentifier(AccessibilityID.Player.volumeMute)
    }

    // MARK: - Custom Slider

    private static let trackHeight: CGFloat = 4
    private static let thumbSize: CGFloat = 14

    private var showThumb: Bool { isHovering || isDragging }

    private var customSlider: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = sliderVolume / effectiveMax
            let thumbX = fraction * width

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: Self.trackHeight)

                // Filled track
                Capsule()
                    .fill(DS.Colors.accent)
                    .frame(width: max(0, thumbX), height: Self.trackHeight)

                // Thumb (visible on hover/drag only)
                if showThumb {
                    Circle()
                        .fill(DS.Colors.accent)
                        .frame(width: Self.thumbSize, height: Self.thumbSize)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: thumbX - Self.thumbSize / 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            viewModel.setAdjustingVolume(true)
                        }
                        let clamped = max(0, min(1, value.location.x / width))
                        sliderVolume = clamped * effectiveMax
                    }
                    .onEnded { value in
                        let clamped = max(0, min(1, value.location.x / width))
                        sliderVolume = clamped * effectiveMax
                        viewModel.setVolume(Int(sliderVolume))
                        isDragging = false
                        viewModel.setAdjustingVolume(false)
                    }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
        .frame(height: Self.thumbSize)
        .accessibilityIdentifier(AccessibilityID.Player.volumeSlider)
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(sliderVolume)) percent")
    }

    private var dBLabel: some View {
        Text(dBString(for: sliderVolume))
            .typography(.secondary)
            .frame(width: 52, alignment: .trailing)
            .monospacedDigit()
    }

    // MARK: - Volume Icon

    private var volumeIcon: String {
        let level = Int(sliderVolume)
        let max = Int(effectiveMax)
        if state.isMuted || level == 0 {
            return "speaker.slash.fill"
        } else if level < max / 3 {
            return "speaker.wave.1.fill"
        } else if level < max * 2 / 3 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    // MARK: - dB Conversion

    /// Approximate dB from HEOS 0-100 range. Marantz amps map roughly -80 dB to +18 dB.
    private func dBString(for volume: Double) -> String {
        if state.isMuted || volume == 0 { return "-\u{221E} dB" } // -∞ dB
        let dB = -80.0 + (volume / 100.0) * 98.0
        if dB >= 0 {
            return String(format: "+%.0f dB", dB)
        }
        return String(format: "%.0f dB", dB)
    }
}
