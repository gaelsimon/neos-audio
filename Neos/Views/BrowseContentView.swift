import SwiftUI
import NeosDomain

struct BrowseContentView: View {
    let state: AppState
    let browseVM: BrowseViewModel

    @State private var showCompactHeader = false
    @State private var stationImageTarget: BrowseItem?
    @State private var showAddFavorite = false

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

    /// True when at least one item has a non-empty artist string.
    private var showArtistColumn: Bool {
        browseVM.items.contains { $0.artist != nil && !($0.artist?.isEmpty ?? true) }
    }

    /// True when at least one item has a non-empty album string.
    private var showAlbumColumn: Bool {
        browseVM.items.contains { $0.album != nil && !($0.album?.isEmpty ?? true) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let source = browseVM.selectedSource, !source.available {
                unavailableServiceView(source)
            } else if let error = browseVM.errorMessage {
                if state.signedInUser == nil && isAuthError(error) {
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
        .popover(item: $stationImageTarget) { item in
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header (not lazy; GeometryReader stays active during scroll)
                if browseVM.isInContainer, let current = browseVM.browseStack.last {
                    containerHeader(current)
                        .overlay(
                            GeometryReader { geo in
                                let maxY = geo.frame(in: .named("browse_scroll")).maxY
                                Color.clear.preference(key: ScrollOffsetKey.self, value: maxY)
                            }
                        )
                        .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                            showCompactHeader = maxY < 20
                        }
                } else {
                    sourceHeader
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
        .overlay(alignment: .top) {
            if showCompactHeader, browseVM.isInContainer, let current = browseVM.browseStack.last {
                compactContainerHeader(current)
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

    private func artistViewHandler(for item: BrowseItem) -> (() -> Void)? {
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
    private var itemNoun: String {
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
                    ForEach(Array(browsableItems.enumerated()), id: \.element.id) { index, item in
                        BrowseGridTile(item: item) {
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
                    ForEach(Array(browsableItems.enumerated()), id: \.element.id) { index, item in
                        BrowseItemRow(
                            item: item,
                            isNowPlaying: false,
                            isLoading: false,
                            isAddingToQueue: false,
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
                            .padding(.leading, 54)
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
                let listItems = isTrackList
                    ? browseVM.items.filter { $0.playable && !$0.browsable }
                    : playableItems
                ForEach(Array(listItems.enumerated()), id: \.element.id) { index, item in
                    Group {
                        if isTrackList {
                            TrackListRow(
                                index: index + 1,
                                name: item.name,
                                artist: item.artist,
                                album: item.album,
                                imageURL: item.imageURL,
                                isNowPlaying: isNowPlaying(item),
                                showArtist: showArtistColumn,
                                showAlbum: showAlbumColumn,
                                onArtistTap: artistViewHandler(for: item),
                                isResolvingArtist: browseVM.resolvingArtistName != nil && browseVM.resolvingArtistName == item.artist,
                                onPlayNext: playNextHandler(for: item),
                                onAddToQueue: addToQueueHandler(for: item),
                                onArtistView: artistViewHandler(for: item),
                                onAlbumView: albumViewHandler(for: item),
                                serviceOptions: browseContextOptions,
                                onServiceOption: { option in browseVM.executeServiceOption(option, for: item) },
                                state: state,
                                imageKey: item.imageKey,
                                onSetCustomImage: item.imageKey != nil ? { stationImageTarget = item } : nil
                            ) {
                                browseVM.playItem(item)
                            }
                        } else {
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
                                .padding(.leading, 54)
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

    // MARK: - Compact Sticky Header

    private func compactContainerHeader(_ target: BrowseTarget) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            containerArtwork(target, size: 40, cornerRadius: DS.Radius.small)

            Text(target.name)
                .typography(.secondaryEmphasis)
                .lineLimit(1)

            if let source = serviceSource(for: target) {
                ServiceBranding.serviceIcon(for: source, size: 20)
            }

            Spacer()

            if hasPlayableItems {
                CircularIconButton(
                    icon: DS.Icons.playing,
                    size: .small,
                    style: .primary,
                    action: { browseVM.playContainer() }
                )
                .help("Play")

                CircularIconButton(
                    icon: DS.Icons.addedToQueue,
                    size: .small,
                    style: .secondary,
                    action: { browseVM.addContainerToQueue() }
                )
                .help("Add to Queue")
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.background)
    }

    // MARK: - Source Header (root level, scrolls)

    private var sourceHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            if isInputSource, browseVM.browseStack.count > 1,
               let current = browseVM.browseStack.last,
               let root = browseVM.browseStack.first,
               let source = state.musicSources.first(where: { $0.sid == root.sid }) {
                // Inside an input source sub-level; keep the source icon, show amp name
                ServiceBranding.serviceIcon(for: source, size: DS.ImageSize.serviceIcon)
                Text(current.name)
                    .typography(.pageTitle)
                    .lineLimit(1)
            } else if let target = browseVM.browseStack.first,
               let source = state.musicSources.first(where: { $0.sid == target.sid }) {
                ServiceBranding.serviceLabel(
                    for: source,
                    iconSize: DS.ImageSize.serviceIcon,
                    style: .pageTitle
                )
            } else {
                Text(browseVM.browseStack.last?.name ?? "Browse")
                    .typography(.pageTitle)
                    .lineLimit(1)
            }

            if browseVM.isLoading {
                Spinner(size: 16, lineWidth: 2)
            }

            Spacer()

            if browseVM.isFavoritesSource {
                HoverButton(action: { showAddFavorite = true }) { hovered in
                    Image(systemName: "plus")
                        .font(DS.IconFont.lg)
                        .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                }
                .help("Add Station")
                .popover(isPresented: $showAddFavorite) {
                    AddFavoriteForm(
                        browseVM: browseVM,
                        state: state,
                        onDismiss: { showAddFavorite = false }
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.xxl)
        .padding(.bottom, DS.Spacing.xl)
    }

    // MARK: - Container Artwork (patchwork or single image)

    @ViewBuilder
    private func containerArtwork(_ target: BrowseTarget, size: CGFloat, cornerRadius: CGFloat) -> some View {
        if !target.imageURL.isEmpty {
            CachedAsyncImage(
                url: URL(string: target.imageURL),
                highResURL: ImageURLUpscaler.highResURL(from: target.imageURL).flatMap(URL.init(string:))
            ) {
                artworkPlaceholder(size: size, cornerRadius: cornerRadius)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            let itemImages = browseVM.items
                .map(\.imageURL)
                .filter { !$0.isEmpty }
            let albums = Set(browseVM.items.compactMap(\.album).filter { !$0.isEmpty })
            if albums.count == 1, let firstImage = itemImages.first {
                CachedAsyncImage(
                    url: URL(string: firstImage),
                    highResURL: ImageURLUpscaler.highResURL(from: firstImage).flatMap(URL.init(string:))
                ) {
                    artworkPlaceholder(size: size, cornerRadius: cornerRadius)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                PatchworkArtView(imageURLs: itemImages, size: size, cornerRadius: cornerRadius)
            }
        }
    }

    private func artworkPlaceholder(size: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DS.Colors.surfaceElevated)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: DS.Icons.musicNote)
                    .font(size > 60 ? DS.IconFont.xxxl : DS.IconFont.body)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
    }

    // MARK: - Container Header (album/playlist, scrolls)

    private var hasPlayableItems: Bool {
        browseVM.items.contains { $0.playable }
    }

    /// Primary artwork URL for blur background (container image or first item image).
    /// Uses the original (low-res) URL; high-res is wasteful for a radius-60 blur.
    /// Returns nil only if both container and items have no images.
    private func headerBackgroundURL(_ target: BrowseTarget) -> URL? {
        let raw: String
        if !target.imageURL.isEmpty {
            raw = target.imageURL
        } else {
            let itemImages = browseVM.items.map(\.imageURL).filter { !$0.isEmpty }
            guard let first = itemImages.first else { return nil }
            raw = first
        }
        return URL(string: raw)
    }

    private func containerHeader(_ target: BrowseTarget) -> some View {
        // Compute background URL in the main body so @Observable tracks browseVM.items access.
        // Inside .background {} the observation may not fire, leaving the blur empty on first load.
        let bgURL = headerBackgroundURL(target)
        return VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                containerArtwork(target, size: DS.ImageSize.containerArt, cornerRadius: DS.Radius.large)
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 10)
                    .accessibilityIdentifier(AccessibilityID.Browse.containerArt)

                containerHeaderMetadata(target)
                    .frame(maxHeight: DS.ImageSize.containerArt)
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.xxl + DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xxl + DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let bgURL {
                Color.clear
                    .overlay {
                        CachedAsyncImage(url: bgURL) { Color.clear }
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
                            .opacity(0.5)
                    }
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: DS.Colors.background.opacity(0.3), location: 0.4),
                                .init(color: DS.Colors.background, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
    }

    // MARK: - Container Header Metadata

    @ViewBuilder
    private func containerHeaderMetadata(_ target: BrowseTarget) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(target.name)
                .typography(.pageTitle)
                .lineLimit(2)
                .accessibilityIdentifier(AccessibilityID.Browse.containerTitle)

            if !browseVM.items.isEmpty || !target.serviceName.isEmpty {
                containerSubtitle(target)
            }

            if browseVM.isLoading {
                Spinner(size: 16, lineWidth: 2)
            }

            Spacer(minLength: 0)

            if hasPlayableItems {
                containerActionButtons
            }
        }
    }

    /// Subtitle: service branding first (available immediately), item count second (loads later).
    @ViewBuilder
    private func containerSubtitle(_ target: BrowseTarget) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let source = serviceSource(for: target) {
                HStack(spacing: DS.Spacing.sm) {
                    ServiceBranding.serviceIcon(for: source, size: 24)

                    Text(source.name)
                        .typography(.sectionHeader)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }

            if !browseVM.items.isEmpty {
                Text("\(browseVM.items.count)\(browseVM.hasMore ? "+" : "") \(itemNoun)")
                    .typography(.bodyMedium)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    /// Resolve the MusicSource for the current browse context.
    private func serviceSource(for target: BrowseTarget) -> MusicSource? {
        guard let root = browseVM.browseStack.first else { return nil }
        let source = state.musicSources.first { $0.sid == root.sid }
        // Only show for streaming services, not local/built-in sources
        guard let source, ServiceBranding.hasBrandIdentity(for: source.name) else { return nil }
        return source
    }

    // MARK: - Container Action Buttons

    private var containerActionButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            CircularIconButton(
                icon: DS.Icons.playing,
                size: .large,
                style: .primary,
                action: { browseVM.playContainer() }
            )
            .accessibilityIdentifier(AccessibilityID.Browse.playContainer)
            .help("Play")

            CircularIconButton(
                icon: DS.Icons.addedToQueue,
                size: .medium,
                style: .secondary,
                action: { browseVM.addContainerToQueue() }
            )
            .accessibilityIdentifier(AccessibilityID.Browse.addToQueue)
            .help("Add to Queue")
        }
    }

    // MARK: - Unavailable Service View

    private func unavailableServiceView(_ source: MusicSource) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            ServiceBranding.serviceIcon(for: source, size: 80)
            Text(source.name)
                .typography(.pageTitle)
            Text("This service requires a HEOS account.")
                .typography(.bodyPrimary).foregroundStyle(DS.Colors.textSecondary)

            Button(action: { browseVM.navigateToSettings() }) {
                Text("Sign In")
                    .typography(.bodyEmphasis)
            }
            .buttonStyle(.bordered)
            .tint(DS.Colors.accent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sign In Prompt (browse error)

    private func isAuthError(_ error: String) -> Bool {
        let lower = error.lowercased()
        return lower.contains("not logged in") || lower.contains("not signed in")
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        ErrorStateView(
            message: error,
            actionLabel: "Retry",
            action: { browseVM.retry() }
        )
    }

    private func isNowPlaying(_ item: BrowseItem) -> Bool {
        guard !state.nowPlaying.mid.isEmpty, let mid = item.mid else { return false }
        return state.nowPlaying.mid == mid
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
