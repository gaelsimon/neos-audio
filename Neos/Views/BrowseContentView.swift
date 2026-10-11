import SwiftUI
import NeosDomain

struct BrowseContentView: View {
    let state: AppState
    let browseVM: BrowseViewModel

    @State private var showCompactHeader = false
    @State private var stationImageTarget: BrowseItem?
    @State var showAddFavorite = false

    // MARK: - External Links

    /// Public link for a row, keyed on the browsed source since items rarely carry their own sid.
    private func externalLink(for item: BrowseItem) -> ExternalLinkMenu? {
        ExternalLinkMenu.make(for: item, sourceName: browseVM.selectedSource?.name)
    }

    // MARK: - Input Source Detection

    /// True when the browse source is a physical input selector (AUX, Optical, etc.)
    /// Applies at any browse depth; both the root amp list and the input list within.
    private var isInputSource: Bool {
        guard let source = browseVM.selectedSource else { return false }
        return source.isInputSource
    }

    // MARK: - Track List Detection

    /// True when the current browse result should render as a track list (column layout).
    /// Uses MediaType-driven detection with heuristic fallback for .container type.
    private var isTrackList: Bool {
        if let target = browseVM.browseStack.last {
            switch target.mediaType {
            case .album, .playlist:
                return true
            case .artist, .genre:
                return false
            default:
                break  // fall through to heuristic for .container and others
            }
        }
        // Heuristic fallback for .container type and when browseStack is empty
        guard !browseVM.items.isEmpty else { return false }
        let playableNonBrowsable = browseVM.items.filter { $0.playable && !$0.browsable }
        return !playableNonBrowsable.isEmpty
            && playableNonBrowsable.count >= browseVM.items.count / 2
    }

    private var showArtistColumn: Bool {
        browseVM.items.contains { $0.artist != nil && !($0.artist?.isEmpty ?? true) }
    }

    var trackRows: [BrowseItem] {
        browseVM.items.filter { $0.playable && !$0.browsable }
    }

    private var sharedAlbum: String? {
        TrackListPresentation.sharedAlbum(in: trackRows)
    }

    var sharedArtist: String? {
        sharedAlbum == nil ? nil : TrackListPresentation.sharedArtist(in: trackRows)
    }

    private var trackColumns: (artist: Bool, album: Bool, artwork: Bool) {
        (showArtistColumn, showAlbumColumn, sharedAlbum == nil)
    }

    private var showAlbumColumn: Bool {
        sharedAlbum == nil && browseVM.items.contains { $0.album != nil && !($0.album?.isEmpty ?? true) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let source = browseVM.selectedSource, !source.available,
               !MusicSource.listed(state.musicSources, signedIn: state.signedInUser != nil).contains(where: { $0.sid == source.sid }) {
                unavailableServiceView(source)
            } else if let error = browseVM.errorMessage {
                if isAuthError(error) {
                    SignInPromptView(
                        title: "Sign in to access this service",
                        message: "Connect your HEOS account to browse and play from streaming services.",
                        style: .centered,
                        onSignIn: { browseVM.navigateToSettings() }
                    )
                } else {
                    errorView(error)
                }
            } else if browseVM.items.isEmpty && !browseVM.isLoading {
                EmptyStateView(icon: DS.Icons.musicNote, message: "No items")
            } else {
                scrollableContent
            }
        }
        .accessibilityIdentifier(AccessibilityID.Browse.view)
        // Sheets, not popovers: the image picker becomes the key window, which dismisses a
        // transient popover before either form can be finished.
        .sheet(isPresented: $showAddFavorite) {
            AddFavoriteForm(
                browseVM: browseVM,
                state: state,
                onDismiss: { showAddFavorite = false }
            )
        }
        .sheet(item: $stationImageTarget) { item in
            StationImageEditor(
                mid: item.imageKey ?? "",
                name: item.name,
                currentImageURL: item.imageURL,
                state: state,
                onDismiss: { stationImageTarget = nil }
            )
        }
    }

    // MARK: - Scrollable Content

    private var scrollableContent: some View {
        // Read here, not inside .background: @Observable only tracks browseVM.items from the body.
        let backdropURL = browseVM.isInContainer ? browseVM.browseStack.last.flatMap(headerBackgroundURL) : nil
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header (not lazy; GeometryReader stays active during scroll)
                Group {
                    if browseVM.isInContainer, let current = browseVM.browseStack.last {
                        containerHeader(current, backdropURL: backdropURL)
                    } else {
                        sourceHeader
                    }
                }
                .overlay(
                    GeometryReader { geo in
                        let maxY = geo.frame(in: .named("browse_scroll")).maxY
                        Color.clear.preference(key: ScrollOffsetKey.self, value: maxY)
                    }
                )
                .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                    showCompactHeader = maxY < (backdropURL == nil ? 0 : DS.TopBar.height) + 20
                }

                if isInputSource {
                    // Input source: render card grid, skip track list header and column layout
                    InputSelectorGrid(
                        items: browseVM.items,
                        activeInputMID: state.nowPlaying.mid.isEmpty ? nil : state.nowPlaying.mid,
                        onSelect: { item in
                            if item.isSubSource {
                                browseVM.browseSubSource(item)
                            } else {
                                browseVM.selectInput(item)
                            }
                        }
                    )
                } else {
                    itemsList
                }
            }
        }
        .coordinateSpace(name: "browse_scroll")
        .ignoresSafeArea(edges: backdropURL == nil ? [] : .top)
        .overlay(alignment: .top) {
            if showCompactHeader {
                if browseVM.isInContainer, let current = browseVM.browseStack.last {
                    compactContainerHeader(current)
                } else {
                    compactSourceHeader
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showCompactHeader)
        .id(browseVM.browseStack.map(\.stableID).joined(separator: "/"))
    }

    // MARK: - Track Action Handlers

    private var currentSID: Int {
        browseVM.browseStack.last?.sid ?? browseVM.browseStack.first?.sid ?? 0
    }

    private func playNextHandler(for item: BrowseItem) -> (() -> Void)? {
        guard item.playable else { return nil }
        return { browseVM.addToQueue(item, criteria: .playNext) }
    }

    private func addToQueueHandler(for item: BrowseItem) -> (() -> Void)? {
        guard item.playable else { return nil }
        return { browseVM.addToQueue(item, criteria: .addToEnd) }
    }

    func artistViewHandler(for item: BrowseItem) -> (() -> Void)? {
        let sid = currentSID
        guard let artistName = item.artist,
              isLinkableArtist(artistName),
              let caps = state.serviceCapabilities[sid],
              caps.canBrowseArtists else { return nil }
        return { browseVM.pushArtistSearchNavigate(sid: sid, artistName: artistName) }
    }

    private func albumViewHandler(for item: BrowseItem) -> (() -> Void)? {
        let sid = currentSID
        guard let caps = state.serviceCapabilities[sid],
              caps.canBrowseAlbums,
              let albumName = item.album, !albumName.isEmpty else { return nil }
        return { browseVM.pushAlbumSearchNavigate(sid: sid, albumName: albumName, artistHint: item.artist) }
    }

    private var browseContextOptions: [ServiceOption] {
        browseVM.browseOptions.filter { $0.context == .browse }
    }

    // MARK: - Items List

    /// Types that have visual artwork and deserve a grid layout.
    private static let gridTypes: Set<MediaType> = [.playlist, .album, .artist, .genre]

    /// Browsable items (playlists, albums, etc.) shown as grid tiles.
    private var browsableItems: [BrowseItem] {
        browseVM.items.filter { $0.browsable || $0.isSubSource }
    }

    /// Grid when ALL browsable items are visual types; list otherwise.
    private var useGridForBrowsable: Bool {
        let items = browsableItems
        guard !items.isEmpty else { return false }
        return items.allSatisfy { Self.gridTypes.contains($0.type) }
    }

    /// Playable-only items (songs, stations) shown as list rows.
    private var playableItems: [BrowseItem] {
        browseVM.items.filter { !$0.browsable && !$0.isSubSource }
    }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 160), spacing: DS.Spacing.xl)
    ]

    /// Human-friendly noun for the dominant item type in the current container.
    var itemNoun: String {
        let items = browseVM.items
        guard !items.isEmpty else { return "items" }
        let dominant = items.first?.type ?? .container
        let allSame = items.allSatisfy { $0.type == dominant }
        guard allSame else { return "items" }
        switch dominant {
        case .song:         return "tracks"
        case .station:      return "stations"
        case .album:        return "albums"
        case .artist:       return "artists"
        case .playlist:     return "playlists"
        case .genre:        return "genres"
        case .container:    return "items"
        case .dlnaServer, .heosServer, .heosService, .musicService: return "items"
        }
    }

    @ViewBuilder
    private var itemsList: some View {
        // Browsable items: grid for visual types, list for navigation
        if !browsableItems.isEmpty && !isTrackList {
            if useGridForBrowsable {
                LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xl) {
                    ForEach(Array(browsableItems.enumerated()), id: \.element.id) { _, item in
                        BrowseGridTile(item: item, externalLink: externalLink(for: item), state: state) {
                            if item.browsable {
                                browseVM.browseItem(item)
                            } else if item.isSubSource {
                                browseVM.browseSubSource(item)
                            }
                        }
                        .onAppear {
                            if let globalIndex = browseVM.items.firstIndex(where: { $0.id == item.id }),
                               browseVM.shouldLoadMore(at: globalIndex) {
                                browseVM.loadMore()
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.bottom, DS.Spacing.lg)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(browsableItems.enumerated()), id: \.element.id) { _, item in
                        BrowseItemRow(
                            item: item,
                            isNowPlaying: false,
                            isLoading: false,
                            isAddingToQueue: false,
                            externalLink: externalLink(for: item),
                            state: state,
                            onSetCustomImage: item.imageKey != nil ? { stationImageTarget = item } : nil
                        ) {
                            if item.browsable {
                                browseVM.browseItem(item)
                            } else if item.isSubSource {
                                browseVM.browseSubSource(item)
                            }
                        } onAddToQueue: {}
                        .onAppear {
                            if let globalIndex = browseVM.items.firstIndex(where: { $0.id == item.id }),
                               browseVM.shouldLoadMore(at: globalIndex) {
                                browseVM.loadMore()
                            }
                        }

                        Divider()
                            .foregroundStyle(DS.Colors.border)
                            .padding(.leading, DS.Spacing.lg + DS.ImageSize.listRow + DS.Spacing.md)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
        }

        // Track list header (only when there are playable items in track-list mode)
        if isTrackList && !playableItems.isEmpty {
            TrackListHeader(showArtist: showArtistColumn, showAlbum: showAlbumColumn)
                .padding(.top, DS.Spacing.md)
                .padding(.horizontal, DS.Spacing.xxl)
            Divider()
                .foregroundStyle(DS.Colors.border)
                .padding(.horizontal, DS.Spacing.xxl)
        }

        // List of playable items (songs, stations)
        if !playableItems.isEmpty || (isTrackList && !browseVM.items.isEmpty) {
            LazyVStack(alignment: .leading, spacing: DS.TrackList.rowSpacing) {
                let listItems = isTrackList ? trackRows : playableItems
                let columns = trackColumns
                ForEach(Array(listItems.enumerated()), id: \.element.id) { index, item in
                    Group {
                        if isTrackList {
                            trackRow(item, at: index, columns: columns)
                        } else {
                            browseRow(item)
                        }
                    }
                    .onAppear {
                        if let globalIndex = browseVM.items.firstIndex(where: { $0.id == item.id }),
                           browseVM.shouldLoadMore(at: globalIndex) {
                            browseVM.loadMore()
                        }
                    }
                }

                if browseVM.isLoadingMore {
                    HStack {
                        Spacer()
                        Spinner(size: 16, lineWidth: 2)
                            .padding()
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
        } else if browseVM.isLoadingMore {
            HStack {
                Spacer()
                Spinner(size: 16, lineWidth: 2)
                    .padding()
                Spacer()
            }
        }
    }

    private func trackRow(_ item: BrowseItem, at index: Int, columns: (artist: Bool, album: Bool, artwork: Bool)) -> some View {
        TrackListRow(
            index: index + 1,
            name: item.name,
            artist: item.artist,
            album: item.album,
            imageURL: item.imageURL,
            isNowPlaying: isNowPlaying(item),
            showArtist: columns.artist,
            showAlbum: columns.album,
            showArtwork: columns.artwork,
            onArtistTap: artistViewHandler(for: item),
            isResolvingArtist: browseVM.resolvingArtistName != nil && browseVM.resolvingArtistName == item.artist,
            onPlayNext: playNextHandler(for: item),
            onAddToQueue: addToQueueHandler(for: item),
            onArtistView: artistViewHandler(for: item),
            onAlbumView: albumViewHandler(for: item),
            serviceOptions: browseContextOptions,
            onServiceOption: { option in browseVM.executeServiceOption(option, for: item) },
            externalLink: externalLink(for: item),
            state: state,
            imageKey: item.imageKey,
            onSetCustomImage: item.imageKey != nil ? { stationImageTarget = item } : nil
        ) {
            browseVM.playItem(item)
        }
    }

    @ViewBuilder
    private func browseRow(_ item: BrowseItem) -> some View {
        BrowseItemRow(
            item: item,
            isNowPlaying: isNowPlaying(item),
            isLoading: browseVM.playingItemID == item.id,
            isAddingToQueue: browseVM.addingToQueueItemID == item.id,
            onPlayNext: playNextHandler(for: item),
            onArtistView: artistViewHandler(for: item),
            onAlbumView: albumViewHandler(for: item),
            serviceOptions: browseContextOptions,
            onServiceOption: { option in browseVM.executeServiceOption(option, for: item) },
            externalLink: externalLink(for: item),
            state: state,
            onSetCustomImage: item.imageKey != nil ? { stationImageTarget = item } : nil
        ) {
            if item.playable {
                browseVM.playItem(item)
            }
        } onAddToQueue: {
            browseVM.addToQueue(item)
        }

        Divider()
            .foregroundStyle(DS.Colors.border)
            .padding(.leading, DS.Spacing.lg + DS.ImageSize.listRow + DS.Spacing.md)
    }

    private func isNowPlaying(_ item: BrowseItem) -> Bool {
        state.isNowPlaying(item)
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
