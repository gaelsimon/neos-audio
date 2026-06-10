import SwiftUI
import NeosDomain

struct QueueView: View {
    let state: AppState
    let viewModel: QueueViewModel
    let browseVM: BrowseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            queueHeader

            Divider()

            if state.queue.isEmpty && !viewModel.isLoadingQueue {
                EmptyStateView(icon: DS.Icons.playlists, message: "Queue is empty")
                    .padding(20)
            } else {
                // MARK: - Column Header

                TrackListHeader(showArtist: true, showAlbum: true)
                Divider()
                    .foregroundStyle(DS.Colors.border)
                    .padding(.horizontal, DS.Spacing.lg)

                queueList
            }
        }
        .task(id: state.selectedPlayerID) {
            // Skip reload if queue data already exists (EventRouter keeps it current).
            // Only fetch on player change or when queue is empty.
            if state.queue.isEmpty {
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
                HoverButton(action: { viewModel.clearQueue() }) { hovered in
                    Text("Clear")
                        .typography(.secondary)
                        .foregroundStyle(hovered ? .red : .red.opacity(0.7))
                }
                .disabled(viewModel.isClearing)
                .accessibilityIdentifier(AccessibilityID.Queue.clearButton)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: - Queue Items

    private var queueList: some View {
        ScrollView {
            VStack(spacing: DS.TrackList.rowSpacing) {
                ForEach(Array(state.queue.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 0) {
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
                            isResolvingArtist: browseVM.resolvingArtistName != nil && browseVM.resolvingArtistName == item.artist
                        ) {
                            viewModel.playItem(item)
                        }

                        HoverButton(action: { viewModel.removeItem(item) }) { hovered in
                            Image(systemName: DS.Icons.dismiss)
                                .typography(.secondary)
                                .foregroundStyle(hovered ? DS.Colors.textSecondary : DS.Colors.textTertiary)
                        }
                        .padding(.trailing, DS.Spacing.lg)
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
