import SwiftUI
import NeosDomain

struct MenuBarView: View {
    let state: AppState
    let playerVM: PlayerViewModel
    let speakerVM: SpeakerListViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Now playing
            NowPlayingBanner(
                state: state,
                onSeek: { position in playerVM.seek(to: position) }
            )

            Divider()

            // Transport controls
            PlayerControlView(state: state, viewModel: playerVM)
                .padding(.vertical, DS.Spacing.sm)

            // Volume
            VolumeControlView(state: state, viewModel: playerVM)
                .padding(.bottom, DS.Spacing.sm)

            Divider()

            // Speaker picker (compact)
            if state.isConnected && state.players.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(state.players) { player in
                            Button(action: { speakerVM.selectPlayer(player) }) {
                                Text(player.name)
                                    .typography(.secondary)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xs)
                                    .background(
                                        player.pid == state.selectedPlayerID
                                            ? DS.Colors.accent.opacity(0.2)
                                            : Color.clear,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        player.pid == state.selectedPlayerID
                                            ? DS.Colors.accent : .secondary
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("menuBar.speaker.\(player.pid)")
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                Divider()
            }

            // Connection status
            ConnectionStatusView(state: state)
        }
        .frame(width: 280)
    }
}
