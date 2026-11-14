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
            slider
            dBLabel
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Compact Layout (Panel)

    private var compactLayout: some View {
        HStack(spacing: DS.Spacing.sm) {
            muteButton
            slider
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

    // MARK: - Slider

    private var slider: some View {
        AccentSlider(
            value: sliderVolume,
            bounds: 0...max(effectiveMax, 1),
            label: "Volume",
            onEditingChanged: { editing in
                isDragging = editing
                viewModel.setAdjustingVolume(editing)
            },
            onChange: { level in
                sliderVolume = level
                viewModel.setVolume(Int(level))
            }
        )
        .accessibilityIdentifier(AccessibilityID.Player.volumeSlider)
    }

    /// The HEOS level as the device reports it; a dB figure would only hold for one amp model.
    private var dBLabel: some View {
        Text(state.isMuted ? "Muted" : "\(Int(sliderVolume))")
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

}
