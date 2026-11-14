import SwiftUI
import NeosDomain

struct QueueView: View {
    let state: AppState
    let viewModel: QueueViewModel
    let browseVM: BrowseViewModel
    @State private var showClearConfirmation = false
    @Environment(\.listMargin) private var listMargin
    /// Compact rows have no columns to label.
    @Environment(\.isCompactLayout) private var isCompactLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            #if os(macOS)
            queueHeader

            Divider()
            #endif

            if state.queue.isEmpty && !viewModel.isLoadingQueue {
                ContentUnavailableView("Queue Is Empty", systemImage: DS.Icons.playlists)
            } else {
                // MARK: - Column Header

                if !isCompactLayout {
                    TrackListHeader(showArtist: true, showAlbum: true, trailingSlots: 2)
                        .listMargins()
                    Divider()
                        .foregroundStyle(DS.Colors.border)
                        .listMargins()
                }

                queueList
                    .contentMargins(.horizontal, listMargin, for: .scrollContent)
            }
        }
        #if os(iOS)
        .toolbar {
            if viewModel.isLoadingQueue {
                ToolbarItem(placement: .topBarTrailing) { ProgressView() }
            }
            if !state.queue.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) { showClearConfirmation = true }
                        .disabled(viewModel.isClearing)
                        .accessibilityIdentifier(AccessibilityID.Queue.clearButton)
                        .modifier(clearConfirmation)
                }
            }
        }
        #endif
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

    #if os(macOS)
    /// The navigation bar carries the title and these actions on iPhone and iPad.
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
                .modifier(clearConfirmation)
            }
        }
        .pageMargins()
        .padding(.top, DS.Layout.pageTop)
        .padding(.bottom, DS.Spacing.md)
    }
    #endif

    /// On the Clear button itself, so an iPad popover points at it.
    private var clearConfirmation: ClearQueueConfirmation {
        ClearQueueConfirmation(isPresented: $showClearConfirmation) { viewModel.clearQueue() }
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

private struct ClearQueueConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let onClear: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog("Clear Queue", isPresented: $isPresented) {
            Button("Clear Queue", role: .destructive, action: onClear)
        } message: {
            Text("This removes every track from the queue.")
        }
    }
}
