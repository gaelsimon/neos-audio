import SwiftUI
import NeosDomain

struct PlayerControlView: View {
    enum Size {
        case regular   // MenuBar: larger play button, wider spacing
        case compact   // Inline: smaller, tighter
        case bottomBar // Main window bottom bar: wide spacing, flat icons
        case canvas    // Immersive: large play/pause, generous spacing

        var playFont: Font {
            switch self {
            case .regular: DS.IconFont.scaled(36)
            case .compact: DS.IconFont.scaled(28)
            case .bottomBar: DS.IconFont.hero
            case .canvas: DS.IconFont.scaled(44)
            }
        }
        var skipFont: Font {
            switch self {
            case .regular: DS.IconFont.scaled(20)
            case .compact: DS.IconFont.body
            case .bottomBar: DS.IconFont.xl
            case .canvas: DS.IconFont.xxxl
            }
        }
        var modeFont: Font {
            switch self {
            case .regular: DS.IconFont.body
            case .compact: DS.IconFont.scaled(12)
            case .bottomBar: DS.IconFont.body
            case .canvas: DS.IconFont.xl
            }
        }
        var spacing: CGFloat {
            switch self {
            case .regular: 24
            case .compact: 8
            case .bottomBar: 20
            case .canvas: 36
            }
        }
        var playHitSize: CGFloat {
            switch self {
            case .regular: 40
            case .compact: 32
            case .bottomBar: 32
            case .canvas: 48
            }
        }
        var useCirclePlay: Bool {
            switch self {
            case .regular, .compact: true
            case .bottomBar, .canvas: false
            }
        }
        var useEndFillSkip: Bool {
            switch self {
            case .bottomBar, .canvas: true
            case .regular, .compact: false
            }
        }
    }

    let state: AppState
    let viewModel: PlayerViewModel
    var size: Size = .regular

    var body: some View {
        HStack(spacing: size.spacing) {
            HoverButton(action: { viewModel.toggleShuffle() }) { hovered in
                Image(systemName: DS.Icons.shuffle)
                    .font(size.modeFont)
                    .foregroundStyle(state.shuffleMode == .on ? DS.Colors.accent : hovered ? .primary : DS.Colors.textSecondary)
            }
            .help("Shuffle")
            .accessibilityIdentifier(AccessibilityID.Player.shuffle)

            HoverButton(action: { viewModel.previous() }) { hovered in
                Image(systemName: size.useEndFillSkip ? "backward.end.fill" : "backward.fill")
                    .font(size.skipFont)
                    .foregroundStyle(hovered ? .primary : DS.Colors.textSecondary)
            }
            .disabled(viewModel.isSkipping)
            .opacity(viewModel.isSkipping ? 0.5 : 1)
            .help("Previous")
            .accessibilityIdentifier(AccessibilityID.Player.previous)

            HoverButton(action: { viewModel.togglePlayPause() }) { hovered in
                Image(systemName: playPauseIcon)
                    .font(size.playFont)
                    .foregroundStyle(hovered ? Color.white : Color.white.opacity(0.85))
                    .frame(width: size.playHitSize, height: size.playHitSize)
                    .contentShape(Rectangle())
            }
            .help(state.isPlaying ? "Pause" : "Play")
            .accessibilityIdentifier(AccessibilityID.Player.playPause)

            HoverButton(action: { viewModel.next() }) { hovered in
                Image(systemName: size.useEndFillSkip ? "forward.end.fill" : "forward.fill")
                    .font(size.skipFont)
                    .foregroundStyle(hovered ? .primary : DS.Colors.textSecondary)
            }
            .disabled(viewModel.isSkipping)
            .opacity(viewModel.isSkipping ? 0.5 : 1)
            .help("Next")
            .accessibilityIdentifier(AccessibilityID.Player.next)

            HoverButton(action: { viewModel.cycleRepeatMode() }) { hovered in
                Image(systemName: repeatIcon)
                    .font(size.modeFont)
                    .foregroundStyle(state.repeatMode != .off ? DS.Colors.accent : hovered ? .primary : DS.Colors.textSecondary)
            }
            .help("Repeat")
            .accessibilityIdentifier(AccessibilityID.Player.repeatMode)
        }
    }

    private var playPauseIcon: String {
        if size.useCirclePlay {
            state.isPlaying ? "pause.circle.fill" : "play.circle.fill"
        } else {
            state.isPlaying ? "pause.fill" : "play.fill"
        }
    }

    private var repeatIcon: String {
        switch state.repeatMode {
        case .off: "repeat"
        case .onAll: "repeat"
        case .onOne: "repeat.1"
        }
    }
}
