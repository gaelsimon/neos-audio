import SwiftUI
import NeosDomain

/// The full player on iPhone and iPad: the speaker and the artwork over its colour, then the transport and the volume.
struct MobileNowPlayingView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var showsSpeakers = false
    /// Its own: a queue left open beside an iPad's pages must not slide over the player as it opens.
    @State private var showsQueue = false
    /// Narrower than the screen on iPad, where the controls would otherwise run past the artwork's edges.
    @State private var artworkWidth: CGFloat?

    private var playerVM: PlayerViewModel { container.playerVM }

    var body: some View {
        NowPlayingCanvasView(state: state, headerLead: .speaker { showsSpeakers = true })
            .safeAreaInset(edge: .bottom, spacing: 0) { controls }
            .onPreferenceChange(NowPlayingArtworkWidthKey.self) { artworkWidth = $0 }
            .sheet(isPresented: $showsSpeakers) {
                SpeakersSheet(state: state, container: container)
            }
            .sheet(isPresented: queuePresentation) {
                QueuePanelView(state: state, viewModel: container.queuePanelVM)
                    .toastOnTop(state)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .cappedTextSize()
            }
            .toastOnTop(state)
            .cappedTextSize()
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
                            .typography(.bodyPrimary, color: DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    if let source = playingFrom {
                        sourceLine(source)
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
                Button { queuePresentation.wrappedValue = true } label: {
                    Image(systemName: DS.Icons.queue)
                        .font(DS.IconFont.lg)
                        .hitTarget()
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

    /// The panel's flag follows the sheet, so the history refreshes while it shows.
    private var queuePresentation: Binding<Bool> {
        Binding(
            get: { showsQueue },
            set: { isShown in
                showsQueue = isShown
                state.isQueuePanelOpen = isShown
            }
        )
    }

    private var playingFrom: MusicSource? {
        guard let sid = state.nowPlaying.sid else { return nil }
        return state.musicSources.first { $0.sid == sid }
    }

    /// Where the track comes from, and at what quality when the speaker says.
    private func sourceLine(_ source: MusicSource) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            ServiceBranding.serviceIcon(for: source, size: 16)
            Text([source.name, state.trackMetadata?.qualityDescription].compactMap { $0 }.joined(separator: " · "))
                .lineLimit(1)
        }
        .typography(.cardSubtitle)
        .padding(.top, DS.Spacing.xxs)
    }

    /// What the Mac's player bar offers for the track: the service's ratings and favourite, and its links.
    @ViewBuilder
    private var trackMenu: some View {
        let options = state.nowPlayingOptions.filter { Self.menuOptionIcons[$0.id] != nil }
        let link = ExternalLinkMenu.make(for: state.nowPlaying, sources: state.musicSources)
        let pages = [NowPlayingPage.artist, .album].filter(state.canOpen)
        if !options.isEmpty || link != nil || !pages.isEmpty {
            Menu {
                if pages.contains(.artist) {
                    Button("Go to Artist", systemImage: "person") { open(.artist) }
                }
                if pages.contains(.album) {
                    Button("Go to Album", systemImage: "square.stack") { open(.album) }
                }
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
                    .hitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More")
        }
    }

    private func open(_ page: NowPlayingPage) {
        state.pageRequestedFromPlayer = page
        state.isNowPlayingCanvasOpen = false
    }

    private static let menuOptionIcons = [
        ServiceOption.thumbsUpID: "hand.thumbsup",
        ServiceOption.thumbsDownID: "hand.thumbsdown",
        ServiceOption.addToFavoritesID: "heart",
    ]
}
