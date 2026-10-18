import SwiftUI
import NeosDomain

struct QueueView: View {
    let state: AppState
    let viewModel: QueueViewModel
    let browseVM: BrowseViewModel
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            queueHeader

            Divider()

            if state.queue.isEmpty && !viewModel.isLoadingQueue {
                EmptyStateView(icon: DS.Icons.playlists, message: "Queue is empty")
                    .padding(20)
            } else {
                // MARK: - Column Header

                TrackListHeader(showArtist: true, showAlbum: true, trailingSlots: 2)
                    .padding(.horizontal, DS.Spacing.xxl)
                Divider()
                    .foregroundStyle(DS.Colors.border)
                    .padding(.horizontal, DS.Spacing.xxl)

                queueList
                    .contentMargins(.horizontal, DS.Spacing.xxl, for: .scrollContent)
            }
        }
        .task(id: state.selectedPlayerID) {
            // EventRouter keeps a loaded queue current, unless an edit's fetch was lost on the way.
            if state.queue.isEmpty || state.playback.queueNeedsReload {
                viewModel.loadQueue()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Queue.view)
    }

    // MARK: - Header

    private var queueHeader: some View {
        HStack {
            Text("Queue")
                .typography(.pageTitle)
                .accessibilityIdentifier(AccessibilityID.Queue.header)

            if viewModel.isLoadingQueue {
                Spinner(size: 16, lineWidth: 2)
            }

            Spacer()
            if !state.queue.isEmpty {
                TextActionButton(
                    title: "Clear",
                    role: .destructive,
                    isBusy: viewModel.isClearing,
                    accessibilityID: AccessibilityID.Queue.clearButton
                ) { showClearConfirmation = true }
                .disabled(viewModel.isClearing)
                .confirmationDialog("Clear Queue", isPresented: $showClearConfirmation) {
                    Button("Clear Queue", role: .destructive) { viewModel.clearQueue() }
                } message: {
                    Text("This removes every track from the queue.")
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.xxl)
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: - Queue Items

    private var queueList: some View {
        ScrollView {
            VStack(spacing: DS.TrackList.rowSpacing) {
                ForEach(Array(state.queue.enumerated()), id: \.element.id) { index, item in
                    TrackListRow(
                        index: index + 1,
                        name: item.song,
                        artist: item.artist,
                        album: item.album,
                        imageURL: item.imageURL,
                        isNowPlaying: state.nowPlaying.station == nil && item.qid == state.nowPlaying.qid,
                        showArtist: true,
                        showAlbum: true,
                        onAlbumTap: albumTapHandler(for: item),
                        onArtistTap: artistTapHandler(for: item),
                        isResolvingArtist: browseVM.resolvingArtistName != nil && browseVM.resolvingArtistName == item.artist,
                        externalLink: ExternalLinkMenu.make(for: item, sourceName: nil),
                        state: state,
                        onRemove: { viewModel.removeItem(item) }
                    ) {
                        viewModel.playItem(item)
                    }
                    .onAppear {
                        if index >= state.queue.count - 5 {
                            viewModel.loadMoreQueue()
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        Spinner(size: 16, lineWidth: 2)
                            .padding()
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Cross-Link Tap Handlers

    private func albumTapHandler(for item: QueueItem) -> (() -> Void)? {
        guard let sid = state.nowPlaying.sid,
              !item.album.isEmpty,
              let caps = state.serviceCapabilities[sid],
              caps.canBrowseAlbums else {
            return nil
        }
        return {
            browseVM.pushAlbumSearchNavigate(sid: sid, albumName: item.album, artistHint: item.artist)
        }
    }

    private func artistTapHandler(for item: QueueItem) -> (() -> Void)? {
        guard let sid = state.nowPlaying.sid,
              isLinkableArtist(item.artist),
              let caps = state.serviceCapabilities[sid],
              caps.canBrowseArtists else {
            return nil
        }
        return {
            browseVM.pushArtistSearchNavigate(sid: sid, artistName: item.artist)
        }
    }
}
