import Foundation
import NeosDomain
import os

let browseLogger = Logger(subsystem: "com.galela.neos", category: "browse")

/// Context for "See All" search results browsing (search API instead of container API).
struct SearchResultsContext: Equatable {
    let query: String
    let scid: Int
}

/// A snapshot of everything needed to restore a navigation state.
private struct NavigationEntry: Equatable {
    let destination: NavigationDestination
    let browseStack: [BrowseTarget]
    let searchContext: SearchResultsContext?
    // Cached items for instant back-navigation
    var cachedItems: [BrowseItem]?
    var cachedPagination: CachedPagination?

    static func == (lhs: NavigationEntry, rhs: NavigationEntry) -> Bool {
        lhs.destination == rhs.destination
            && lhs.browseStack == rhs.browseStack
            && lhs.searchContext == rhs.searchContext
    }
}

/// Lightweight snapshot of pagination state for cache restoration.
private struct CachedPagination {
    let totalCount: Int?
    let currentOffset: Int
    let hasMore: Bool
}

@Observable
@MainActor
final class BrowseViewModel {
    // Internal (not private); accessed by BrowseViewModel+Playback extension
    let service: any AudioService
    let state: AppState
    let fetchMusicSources: () async throws -> [MusicSource]
    let fetchSource: (_ sid: Int) async throws -> BrowseResult
    let fetchContainer: (_ sid: Int, _ cid: String, _ range: ClosedRange<Int>?) async throws -> BrowseResult

    var items: [BrowseItem] = []
    var browseOptions: [ServiceOption] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var errorMessage: String?
    var playingItemID: String?
    var addingToQueueItemID: String?
    /// Incremented on every sidebar navigation tap, even if destination unchanged.
    var navigationTapCount: Int = 0

    // MARK: - History Stack

    private var history = NavigationHistoryStack<NavigationEntry>(
        root: NavigationEntry(destination: .home, browseStack: [], searchContext: nil)
    )

    var currentDestination: NavigationDestination { history.current.destination }
    var browseStack: [BrowseTarget] { history.current.browseStack }
    var searchContext: SearchResultsContext? { history.current.searchContext }
    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }
    var currentHistoryIndex: Int { history.currentIndex }

    // MARK: - Pagination State

    var pagination = PaginationState(pageSize: 50)
    let browseTask = CancellableTaskHandle()
    let browseTracker = RequestTracker()

    var resolvingArtistName: String?
    var isResolvingArtist: Bool { resolvingArtistName != nil }
    private let artistResolutionTask = CancellableTaskHandle()

    var isResolvingAlbum: Bool = false
    private let albumResolutionTask = CancellableTaskHandle()

    var selectedSource: MusicSource? {
        guard case .browse(let target) = currentDestination else { return nil }
        return state.musicSources.first { $0.sid == target.sid }
    }

    var hasMore: Bool {
        guard isInContainer || searchContext != nil else { return false }
        guard let totalCount = pagination.totalCount else { return true }
        return pagination.currentOffset < totalCount
    }

    var isInContainer: Bool {
        browseStack.last?.cid != nil
    }

    var isFavoritesSource: Bool {
        browseStack.first?.sid == HEOSConstants.favoritesSID
    }

    init(
        service: any AudioService,
        state: AppState,
        getMusicSources: (() async throws -> [MusicSource])? = nil,
        browseSource: ((_ sid: Int) async throws -> BrowseResult)? = nil,
        browseContainer: ((_ sid: Int, _ cid: String, _ range: ClosedRange<Int>?) async throws -> BrowseResult)? = nil
    ) {
        self.service = service
        self.state = state
        self.fetchMusicSources = getMusicSources ?? { try await service.getMusicSources() }
        self.fetchSource = browseSource ?? { sid in try await service.browseSource(sid: sid) }
        self.fetchContainer = browseContainer ?? { sid, cid, range in
            try await service.browseContainer(sid: sid, cid: cid, range: range)
        }
    }

    // MARK: - History Helpers

    private func pushEntry(destination: NavigationDestination, browseStack: [BrowseTarget], searchContext: SearchResultsContext? = nil) {
        snapshotCurrentEntry()
        history.push(NavigationEntry(destination: destination, browseStack: browseStack, searchContext: searchContext))
    }

    /// Save current items and pagination into the history entry before navigating away.
    private func snapshotCurrentEntry() {
        guard case .browse = history.current.destination, !items.isEmpty else { return }
        let snapshotHasMore = hasMore
        history.updateCurrent { entry in
            entry.cachedItems = items
            entry.cachedPagination = CachedPagination(
                totalCount: pagination.totalCount,
                currentOffset: pagination.currentOffset,
                hasMore: snapshotHasMore
            )
        }
    }

    /// After a back/forward move, restore cached items or fetch fresh.
    private func applyCurrentEntry() {
        let entry = history.current
        // Invalidate tracker + cancel any in-flight task so stale responses
        // are rejected by both browseTracker.isCurrent() and Task.isCancelled.
        _ = beginBrowseRequest()
        errorMessage = nil
        isLoading = false
        isLoadingMore = false

        switch entry.destination {
        case .home, .queue, .settings, .ampSettings:
            items = []
        case .browse:
            if let cached = entry.cachedItems {
                items = cached
                if let p = entry.cachedPagination {
                    pagination.restore(totalCount: p.totalCount, currentOffset: p.currentOffset, items: cached)
                    // If there was nothing more to load at snapshot time, pin totalCount
                    // so hasMore stays false and loadMore() doesn't fire spuriously.
                    if !p.hasMore {
                        pagination.markComplete()
                    }
                }
            } else if entry.browseStack.isEmpty {
                items = []
            } else {
                // fetchCurrentBreadcrumb sets isLoading = true itself
                fetchCurrentBreadcrumb()
            }
        }
    }

    // MARK: - Navigation Convenience

    func isBrowsing(sid: Int) -> Bool {
        if case .browse = currentDestination,
           let root = browseStack.first, root.sid == sid {
            return true
        }
        return false
    }

    func pushAlbumCrossLink(sid: Int, cid: String, albumName: String, imageURL: String = "") {
        guard !cid.isEmpty else { return }
        guard let source = resolveSource(sid: sid) else { return }

        if isBrowsing(sid: sid), !browseStack.isEmpty {
            let newStack = browseStack + [BrowseTarget(
                sid: sid, cid: cid, name: albumName, imageURL: imageURL,
                mediaType: .album, serviceName: source.name
            )]
            pushEntry(destination: currentDestination, browseStack: newStack)
            fetchCurrentBreadcrumb()
            return
        }

        navigateToContainer(source: source, containerName: albumName, cid: cid, imageURL: imageURL, mediaType: .album)
    }

    func pushArtistCrossLink(sid: Int, cid: String, artistName: String, imageURL: String = "") {
        guard !cid.isEmpty else { return }
        guard let source = resolveSource(sid: sid) else { return }

        if isBrowsing(sid: sid), !browseStack.isEmpty {
            let newStack = browseStack + [BrowseTarget(
                sid: sid, cid: cid, name: artistName, imageURL: imageURL,
                mediaType: .artist, serviceName: source.name
            )]
            pushEntry(destination: currentDestination, browseStack: newStack)
            fetchCurrentBreadcrumb()
            return
        }

        navigateToContainer(source: source, containerName: artistName, cid: cid, imageURL: imageURL, mediaType: .artist)
    }

    func pushArtistSearchNavigate(sid: Int, artistName: String) {
        resolvingArtistName = artistName

        artistResolutionTask.replace(with: Task {
            defer {
                resolvingArtistName = nil
            }

            do {
                // Find the "Artists" SCID from cached search criteria
                guard let criteria = state.searchCriteria[sid],
                      let artistCriteria = criteria.first(where: {
                          $0.name.localizedCaseInsensitiveContains("Artist")
                      }) else {
                    state.showToast("Artist search not available", icon: DS.Icons.search, style: .error)
                    return
                }

                guard !Task.isCancelled else { return }

                let result = try await service.search(sid: sid, query: artistName, scid: artistCriteria.scid, range: 0...9)

                guard !Task.isCancelled else { return }

                // Find first result with matching name (case-insensitive)
                guard let match = result.items.first(where: {
                    $0.name.localizedCaseInsensitiveCompare(artistName) == .orderedSame
                }) else {
                    state.showToast("Artist not found", icon: DS.Icons.personNotFound, style: .error)
                    return
                }

                guard let cid = match.cid else {
                    state.showToast("Artist not found", icon: DS.Icons.personNotFound, style: .error)
                    return
                }

                pushArtistCrossLink(sid: sid, cid: cid, artistName: artistName, imageURL: match.imageURL)
            } catch {
                if !Task.isCancelled {
                    state.showToast("Artist not found", icon: DS.Icons.personNotFound, style: .error)
                }
            }
        })
    }

    func pushAlbumSearchNavigate(sid: Int, albumName: String, artistHint: String? = nil) {
        isResolvingAlbum = true

        albumResolutionTask.replace(with: Task {
            defer {
                isResolvingAlbum = false
            }

            do {
                guard let criteria = state.searchCriteria[sid],
                      let albumCriteria = criteria.first(where: {
                          $0.name.localizedCaseInsensitiveContains("Album")
                      }) else {
                    state.showToast("Album search not available", icon: DS.Icons.search, style: .error)
                    return
                }

                guard !Task.isCancelled else { return }

                // Include artist in the query so the service ranks the correct album higher
                // (e.g. "Best Of Daft Punk" instead of just "Best Of")
                let query: String
                if let hint = artistHint, !hint.isEmpty {
                    query = "\(albumName) \(hint)"
                } else {
                    query = albumName
                }

                let result = try await service.search(sid: sid, query: query, scid: albumCriteria.scid, range: 0...9)

                guard !Task.isCancelled else { return }

                guard let match = result.items.first(where: {
                    $0.name.localizedCaseInsensitiveCompare(albumName) == .orderedSame
                }), let cid = match.cid else {
                    state.showToast("Album not found", icon: DS.Icons.search, style: .error)
                    return
                }

                pushAlbumCrossLink(sid: sid, cid: cid, albumName: albumName, imageURL: match.imageURL)
            } catch {
                if !Task.isCancelled {
                    state.showToast("Album not found", icon: DS.Icons.search, style: .error)
                }
            }
        })
    }

    /// Resolve a music source by sid, with fallback creation if sources haven't loaded yet.
    private func resolveSource(sid: Int) -> MusicSource? {
        if let source = state.musicSources.first(where: { $0.sid == sid }) {
            return source
        }
        // Sources may not have loaded yet; construct a minimal source so navigation can proceed.
        // The browse API only needs the sid; name/imageURL are cosmetic for the breadcrumb.
        browseLogger.warning("Music source sid=\(sid) not found in loaded sources, using fallback")
        return MusicSource(sid: sid, name: "Music Service")
    }

    // MARK: - Navigation Actions

    func navigateToHome() {
        pushEntry(destination: .home, browseStack: [])
        navigationTapCount += 1
        browseTask.cancel()
        items = []
    }

    func selectSource(_ source: MusicSource) {
        let rootTarget = BrowseTarget(sid: source.sid, name: source.name, imageURL: source.imageURL, serviceName: source.name)
        let newDest = NavigationDestination.browse(rootTarget)
        let newStack = [rootTarget]
        pushEntry(destination: newDest, browseStack: newStack)
        navigationTapCount += 1
        fetchBrowseRoot(source)
    }

    func navigateToContainer(source: MusicSource, containerName: String, cid: String, imageURL: String = "", mediaType: MediaType = .container) {
        let rootTarget = BrowseTarget(sid: source.sid, name: source.name, imageURL: source.imageURL, serviceName: source.name)
        let newDest = NavigationDestination.browse(rootTarget)
        let newStack = [
            rootTarget,
            BrowseTarget(sid: source.sid, cid: cid, name: containerName, imageURL: imageURL, mediaType: mediaType, serviceName: source.name)
        ]
        pushEntry(destination: newDest, browseStack: newStack)
        loadServiceCapabilitiesIfNeeded(sid: source.sid)
        fetchCurrentBreadcrumb()
    }

    func navigateToSearchResults(source: MusicSource, categoryName: String, query: String, scid: Int) {
        let rootTarget = BrowseTarget(sid: source.sid, name: source.name, imageURL: source.imageURL, serviceName: source.name)
        let newDest = NavigationDestination.browse(rootTarget)
        let ctx = SearchResultsContext(query: query, scid: scid)
        let newStack = [
            rootTarget,
            BrowseTarget(sid: source.sid, name: "\(categoryName) Search for \"\(query)\"", serviceName: source.name)
        ]
        pushEntry(destination: newDest, browseStack: newStack, searchContext: ctx)
        fetchCurrentBreadcrumb()
    }

    func selectQueue() {
        pushEntry(destination: .queue, browseStack: [])
        navigationTapCount += 1
        browseTask.cancel()
        items = []
    }

    func navigateToSettings() {
        pushEntry(destination: .settings, browseStack: [])
        browseTask.cancel()
        items = []
    }

    func navigateToAmpSettings() {
        pushEntry(destination: .ampSettings, browseStack: [])
        browseTask.cancel()
        items = []
    }

    func browseItem(_ item: BrowseItem) {
        guard item.browsable, let cid = item.cid else { return }
        let sid = browseStack.last?.sid ?? 0
        let serviceName = browseStack.first?.serviceName ?? ""
        let newStack = browseStack + [BrowseTarget(
            sid: sid,
            cid: cid,
            name: item.name,
            imageURL: item.imageURL,
            mediaType: item.type,
            serviceName: serviceName
        )]
        pushEntry(destination: currentDestination, browseStack: newStack)
        fetchCurrentBreadcrumb()
    }

    /// Navigate into a sub-source (e.g., a DLNA server within Local Music).
    /// Pushes a new BrowseTarget with the sub-source's own SID onto the existing stack.
    /// Preserves the parent stack entry so back-nav returns to the meta-source.
    func browseSubSource(_ item: BrowseItem) {
        guard let sid = item.sid else { return }
        let serviceName = browseStack.first?.serviceName ?? ""
        let newStack = browseStack + [BrowseTarget(
            sid: sid,
            name: item.name,
            imageURL: item.imageURL,
            mediaType: item.type,
            serviceName: serviceName
        )]
        pushEntry(destination: currentDestination, browseStack: newStack)
        fetchCurrentBreadcrumb()
    }

    func navigateToBreadcrumb(at index: Int) {
        guard index < browseStack.count - 1 else { return }
        let truncatedStack = Array(browseStack.prefix(index + 1))
        pushEntry(destination: currentDestination, browseStack: truncatedStack)
        fetchCurrentBreadcrumb()
    }

    func goBack() {
        snapshotCurrentEntry()
        guard history.goBack() != nil else { return }
        applyCurrentEntry()
    }

    func goForward() {
        snapshotCurrentEntry()
        guard history.goForward() != nil else { return }
        applyCurrentEntry()
    }

    var currentLocationName: String {
        switch currentDestination {
        case .home: return "Home"
        case .queue: return "Queue"
        case .settings: return "Settings"
        case .ampSettings: return "Amp Settings"
        case .browse:
            return browseStack.last?.name ?? "Browse"
        }
    }

    func retry() {
        fetchCurrentBreadcrumb()
    }

    func shouldLoadMore(at index: Int) -> Bool {
        pagination.shouldLoadMore(at: index, itemCount: items.count) && hasMore
    }
}
