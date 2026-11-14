import SwiftUI
import NeosDomain

/// The full player on iPhone and iPad: the speaker and the artwork over its colour, then the transport and the volume.
struct MobileNowPlayingView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var showsSpeakers = false
    /// Narrower than the screen on iPad, where the controls would otherwise run past the artwork's edges.
    @State private var artworkWidth: CGFloat?

    private var playerVM: PlayerViewModel { container.playerVM }

    var body: some View {
        NowPlayingCanvasView(state: state, onShowSpeakers: { showsSpeakers = true })
            .safeAreaInset(edge: .bottom, spacing: 0) { controls }
            .onPreferenceChange(NowPlayingArtworkWidthKey.self) { artworkWidth = $0 }
            .sheet(isPresented: $showsSpeakers) {
                SpeakersSheet(state: state, container: container)
            }
            .sheet(isPresented: Bindable(state).isQueuePanelOpen) {
                QueuePanelView(state: state, viewModel: container.queuePanelVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }

    private var controls: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(state.nowPlaying.displayedTitle)
                        .typography(.sectionHeader)
                        .lineLimit(1)
                    if !state.nowPlaying.artist.isEmpty {
                        Text(state.nowPlaying.artist)
                            .typography(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                trackMenu
            }

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
        // The artwork's colour is behind these; the orange would clash with it.
        .environment(\.sliderFill, .white)
        .frame(maxWidth: artworkWidth)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .disabled(!state.isConnected)
    }

    /// What the Mac's player bar offers for the track: the service's ratings and favourite, and its links.
    @ViewBuilder
    private var trackMenu: some View {
        let options = state.nowPlayingOptions.filter { Self.menuOptionIcons[$0.id] != nil }
        let link = ExternalLinkMenu.make(for: state.nowPlaying, sources: state.musicSources)
        if !options.isEmpty || link != nil {
            Menu {
                ForEach(options) { option in
                    Button(option.name, systemImage: Self.menuOptionIcons[option.id] ?? DS.Icons.musicNote) {
                        playerVM.executeServiceOption(option)
                    }
                }
                if let link {
                    ExternalLinkMenuItems(link: link, state: state)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(DS.IconFont.lg)
                    .frame(width: DS.HitTarget.button, height: DS.HitTarget.button)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More")
        }
    }

    private static let menuOptionIcons = [
        ServiceOption.thumbsUpID: "hand.thumbsup",
        ServiceOption.thumbsDownID: "hand.thumbsdown",
        ServiceOption.addToFavoritesID: "heart",
    ]
}
