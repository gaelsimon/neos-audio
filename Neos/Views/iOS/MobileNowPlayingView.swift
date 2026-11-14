import SwiftUI

/// The full player on iPhone and iPad: the artwork over its colour, then the transport and the volume.
struct MobileNowPlayingView: View {
    let state: AppState
    let container: ViewModelContainer

    private var playerVM: PlayerViewModel { container.playerVM }

    var body: some View {
        NowPlayingCanvasView(state: state)
            .safeAreaInset(edge: .bottom, spacing: 0) { controls }
            .sheet(isPresented: Bindable(state).isQueuePanelOpen) {
                QueuePanelView(state: state, viewModel: container.queuePanelVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }

    private var controls: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.xs) {
                Text(state.nowPlaying.displayedTitle)
                    .typography(.sectionHeader)
                    .lineLimit(1)
                if !state.nowPlaying.artist.isEmpty {
                    Text(state.nowPlaying.artist)
                        .typography(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            ProgressBarView(
                playbackPosition: state.playbackPosition,
                playbackDuration: state.playbackDuration,
                lastProgressUpdate: state.lastProgressUpdate,
                isPlaying: state.isTimelineRunning,
                nowPlayingMID: state.nowPlaying.mid,
                onSeek: { playerVM.seek(to: $0) }
            )

            PlayerControlView(state: state, viewModel: playerVM, size: .canvas)

            HStack(spacing: DS.Spacing.md) {
                VolumeControlView(state: state, viewModel: playerVM, style: .compact)
                Button { state.isQueuePanelOpen = true } label: {
                    Image(systemName: DS.Icons.queue)
                        .font(DS.IconFont.lg)
                        .frame(width: DS.HitTarget.button, height: DS.HitTarget.button)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Queue")
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .disabled(!state.isConnected)
    }
}
