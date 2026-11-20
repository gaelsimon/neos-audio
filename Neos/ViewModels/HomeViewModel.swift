import Foundation
import NeosDomain

struct ServiceCategoryKey: Hashable {
    let sid: Int
    let categoryIndex: Int
}

@Observable
@MainActor
final class HomeViewModel {
    private let service: any AudioService
    private let state: AppState

    // MARK: - Personal Content

    var recentlyPlayed: [BrowseItem] = []
    var favorites: [BrowseItem] = []
    var isLoadingRecents = false
    var isLoadingFavorites = false
    private let homePageSize: Int = 20
    private let recentsTask = CancellableTaskHandle()
    private let favoritesTask = CancellableTaskHandle()
    private let recentsTracker = RequestTracker()
    private let favoritesTracker = RequestTracker()

    // MARK: - Service Content

    var serviceCategories: [ServiceCategoryKey: [BrowseItem]] = [:]
    var serviceCategoryNames: [ServiceCategoryKey: String] = [:]
    var serviceCategoryCIDs: [ServiceCategoryKey: String] = [:]
    var loadingServiceSIDs: Set<Int> = []
    var hiddenSIDs: Set<Int> = HomePreferences.hiddenSIDs()

    /// Single sequential task: the speaker firmware only handles one browse at a time.
    private let serviceProbeTask = CancellableTaskHandle()
    private let serviceTracker = RequestTracker()

    // MARK: - Source Observation

    /// Tracks which SIDs have already been loaded to avoid redundant fetches.
    private var loadedSIDs: Set<Int> = []
    /// Whether personal content (recents + favorites) has been loaded.
    private var hasLoadedPersonal = false
    /// Task that observes musicSources changes on AppState.
    private let sourceObservationTask = CancellableTaskHandle()
    private var sourceObservationStarted = false

    /// Maximum depth to probe into a service's container hierarchy.
    private let maxProbeDepth = 3
    /// Maximum number of categories to show per service.
    private let maxCategoriesPerService = 4

    init(service: any AudioService, state: AppState) {
        self.service = service
        self.state = state
        restoreFromCache()
    }

    // MARK: - Computed Properties

    var streamingSources: [MusicSource] {
        state.musicSources.filter { !HEOSConstants.librarySIDs.contains($0.sid) }
    }

    var visibleStreamingSources: [MusicSource] {
        streamingSources.filter {
            !hiddenSIDs.contains($0.sid)
                && $0.available
                && $0.type == "music_service"
        }
    }

    // MARK: - Loading

    /// Called from HomeView.task. Starts observation of musicSources and loads personal content.
    /// Safe to call multiple times -- idempotent.
    func loadHome() {
        loadPersonalContentIfNeeded()
        loadNewServiceContent()
        startObservingSourceChanges()
    }

    /// Manual refresh -- reloads everything regardless of prior state.
    func refresh() {
        loadRecentlyPlayed()
        loadFavorites()
        loadedSIDs.removeAll()
        loadAllServiceContent()
    }

    func resetForAccountChange() {
        HomeCacheStore.clearAll()
        recentlyPlayed = []
        favorites = []
        serviceCategories = [:]
        serviceCategoryNames = [:]
        serviceCategoryCIDs = [:]
        hasLoadedPersonal = true
        refresh()
    }

    /// Loads personal content (recents + favorites) exactly once.
    private func loadPersonalContentIfNeeded() {
        guard !hasLoadedPersonal else { return }
        hasLoadedPersonal = true
        loadRecentlyPlayed()
        loadFavorites()
    }

    /// Loads service content only for sources that haven't been loaded yet.
    /// This is the key fix for the race condition: called whenever musicSources changes.
    private func loadNewServiceContent() {
        let newSources = visibleStreamingSources.filter { !loadedSIDs.contains($0.sid) }
        guard !newSources.isEmpty else { return }

        let cacheIsFresh = !HomeCacheStore.isStale()
        var needsProbe: [MusicSource] = []

        for source in newSources {
            restoreCachedServiceContent(for: source.sid)
            loadedSIDs.insert(source.sid)
            // Probing costs 15-40 serialized browses; skip it while the cache still holds this service.
            if !cacheIsFresh || !hasCachedCategories(for: source.sid) {
                needsProbe.append(source)
            }
        }

        guard !needsProbe.isEmpty else { return }
        startSequentialProbe(for: needsProbe)
    }

    private func hasCachedCategories(for sid: Int) -> Bool {
        serviceCategories[ServiceCategoryKey(sid: sid, categoryIndex: 0)] != nil
    }

    // MARK: - Source Observation

    /// Loads what new sources bring, and the services a dropped connection cut off once it is back.
    private func startObservingSourceChanges() {
        guard !sourceObservationStarted else { return }
        sourceObservationStarted = true
        sourceObservationTask.replace(with: Task { [weak self] in
            while !Task.isCancelled {
                let sourcesBefore = self?.state.musicSources
                // A reconnect brings back the same sources, which notify nothing: the connection says it is back.
                let changed = await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self?.state.musicSources
                        _ = self?.state.isConnected
                    } onChange: {
                        continuation.resume(returning: true)
                    }
                }
                guard changed, !Task.isCancelled else { break }
                await Task.yield()
                guard let self else { break }
                // Away from the speaker, only new sources are worth a look.
                if !state.isConnected, state.musicSources == sourcesBefore { continue }
                loadNewServiceContent()
            }
        })
    }

    func loadRecentlyPlayed() {
        let requestID = recentsTracker.next()
        isLoadingRecents = true
        recentsTask.replace(with: Task {
            do {
                let history = try await HistoryLoader.load(
                    service: service, trackLimit: homePageSize
                )
                guard recentsTracker.isCurrent(requestID), !Task.isCancelled else { return }
                recentlyPlayed = history.tracks
                HomeCacheStore.saveRecents(history.tracks)
            } catch {
                state.reportNonFatal(source: "HomeViewModel", message: "Failed to load recents: \(error.localizedDescription)")
            }
            guard recentsTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingRecents = false
        })
    }

    func loadFavorites() {
        let requestID = favoritesTracker.next()
        isLoadingFavorites = true
        favoritesTask.replace(with: Task {
            do {
                // Browse top-level to find STATIONS container
                let topLevel = try await service.browseSource(sid: HEOSConstants.favoritesSID)
                guard favoritesTracker.isCurrent(requestID), !Task.isCancelled else { return }

                let stationsContainer = topLevel.items.first {
                    $0.name.lowercased().contains("station") && $0.browsable
                }

                if let stationsContainer, let cid = stationsContainer.cid {
                    let result = try await service.browseContainer(
                        sid: HEOSConstants.favoritesSID, cid: cid, range: 0...(homePageSize - 1)
                    )
                    guard favoritesTracker.isCurrent(requestID), !Task.isCancelled else { return }
                    favorites = result.items
                    HomeCacheStore.saveFavorites(result.items)
                    state.cacheImageURLs(from: result.items)
                } else {
                    // Fallback: show top-level items directly
                    let items = topLevel.items.filter { $0.playable || !$0.browsable }
                    favorites = Array(items.prefix(homePageSize))
                    HomeCacheStore.saveFavorites(favorites)
                    state.cacheImageURLs(from: favorites)
                }
            } catch {
                state.reportNonFatal(source: "HomeViewModel", message: "Failed to load favorites: \(error.localizedDescription)")
            }
            guard favoritesTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingFavorites = false
        })
    }

    // MARK: - Service Content

    func loadAllServiceContent() {
        let sources = visibleStreamingSources
        for source in sources {
            loadedSIDs.insert(source.sid)
            loadingServiceSIDs.insert(source.sid)
        }

        startSequentialProbe(for: sources)
    }

    /// Probes services one at a time; the firmware serves a single browse at a time (BrowseService gates it).
    private func startSequentialProbe(for sources: [MusicSource]) {
        let requestID = serviceTracker.next()

        // Mark all new sources as loading
        for source in sources {
            loadingServiceSIDs.insert(source.sid)
        }

        serviceProbeTask.replace(with: Task {
            for source in sources {
                guard serviceTracker.isCurrent(requestID), !Task.isCancelled else { return }

                let finished = await discoverServiceCategories(
                    sid: source.sid,
                    sourceName: source.name,
                    requestID: requestID
                )

                if serviceTracker.isCurrent(requestID), !Task.isCancelled {
                    loadingServiceSIDs.remove(source.sid)
                    if finished {
                        HomeCacheStore.markUpdated()
                    } else {
                        // Probed again once the speaker is back.
                        loadedSIDs.remove(source.sid)
                    }
                }
            }
        })
    }

    /// False when the connection went away mid-probe: what the cache holds stays until a probe completes.
    private func discoverServiceCategories(sid: Int, sourceName: String, requestID: Int) async -> Bool {
        do {
            // Step 1: Get the service's top-level menu
            let topLevel = try await service.browseSource(sid: sid)
            guard serviceTracker.isCurrent(requestID), !Task.isCancelled else { return true }

            let browsableContainers = topLevel.items.filter { $0.browsable }
            guard !browsableContainers.isEmpty else {
                clearServiceData(for: sid)
                return true
            }

            // Step 2: Probe each top-level container for content.
            // Fresh results overwrite cached data in-place at each category index,
            // so the UI keeps showing cached cards until fresh ones replace them.
            var categoryIndex = 0
            for container in browsableContainers {
                guard categoryIndex < maxCategoriesPerService else { break }
                guard serviceTracker.isCurrent(requestID), !Task.isCancelled else { return true }
                guard let cid = container.cid else { continue }

                try await probeContainer(
                    sid: sid,
                    cid: cid,
                    leafName: container.name,
                    categoryIndex: &categoryIndex,
                    depth: 0,
                    requestID: requestID
                )
            }

            // Clean up any leftover cached slots beyond what was discovered
            for i in categoryIndex..<maxCategoriesPerService {
                let key = ServiceCategoryKey(sid: sid, categoryIndex: i)
                serviceCategories.removeValue(forKey: key)
                serviceCategoryNames.removeValue(forKey: key)
                serviceCategoryCIDs.removeValue(forKey: key)
                HomeCacheStore.clearServiceCategory(sid: sid, categoryIndex: i)
            }
            return true
        } catch {
            state.reportNonFatal(source: "HomeViewModel", message: "Failed to load service content: \(error.localizedDescription)")
            return !ConnectionLoss.matches(error)
        }
    }

    /// Goes down a service's menus until a level holds something to play, up to `maxProbeDepth`.
    @discardableResult
    private func probeContainer(
        sid: Int,
        cid: String,
        leafName: String,
        categoryIndex: inout Int,
        depth: Int,
        requestID: Int
    ) async throws -> Bool {
        guard depth < maxProbeDepth, categoryIndex < maxCategoriesPerService else { return false }
        guard serviceTracker.isCurrent(requestID), !Task.isCancelled else { return false }

        do {
            // Browse WITHOUT range first. Menu containers may not support range.
            // If this returns items, we'll trim to homePageSize for display.
            let result = try await service.browseContainer(sid: sid, cid: cid)
            guard serviceTracker.isCurrent(requestID), !Task.isCancelled else { return false }

            let items = result.items
            guard !items.isEmpty else { return false }

            // Check if we found actual content (playable items or leaf items)
            let hasContent = items.contains { $0.playable || !$0.browsable }

            if hasContent {
                // Found content -- create a category using the leaf container name only
                let displayItems = Array(items.prefix(homePageSize))
                let key = ServiceCategoryKey(sid: sid, categoryIndex: categoryIndex)
                serviceCategories[key] = displayItems
                serviceCategoryNames[key] = leafName
                serviceCategoryCIDs[key] = cid
                state.cacheImageURLs(from: displayItems)

                HomeCacheStore.saveServiceCategory(
                    sid: sid,
                    categoryIndex: categoryIndex,
                    name: leafName,
                    cid: cid,
                    items: displayItems
                )
                categoryIndex += 1
                return true
            }

            // No content yet -- all items are browsable containers.
            // Probe deeper into each sub-container.
            let subContainers = items.filter { $0.browsable }
            for sub in subContainers {
                guard categoryIndex < maxCategoriesPerService else { break }
                guard serviceTracker.isCurrent(requestID), !Task.isCancelled else { return false }
                guard let subCid = sub.cid else { continue }

                // Use only the sub-container's name as the leaf label
                let found = try await probeContainer(
                    sid: sid,
                    cid: subCid,
                    leafName: sub.name,
                    categoryIndex: &categoryIndex,
                    depth: depth + 1,
                    requestID: requestID
                )
                _ = found
            }

            return categoryIndex > 0
        } catch {
            // A container the service refuses is skipped; a lost connection ends the whole probe.
            if ConnectionLoss.matches(error) { throw error }
            return false
        }
    }

    // MARK: - Cache

    /// Clears in-memory and persisted category data for a given SID.
    /// Called before writing fresh discovery results to prevent stale cross-contamination.
    private func clearServiceData(for sid: Int) {
        for i in 0..<maxCategoriesPerService {
            let key = ServiceCategoryKey(sid: sid, categoryIndex: i)
            serviceCategories.removeValue(forKey: key)
            serviceCategoryNames.removeValue(forKey: key)
            serviceCategoryCIDs.removeValue(forKey: key)
        }
        HomeCacheStore.clearServiceCategories(for: sid)
    }

    private func restoreFromCache() {
        let cachedRecents = HomeCacheStore.loadRecents()
        if !cachedRecents.isEmpty {
            recentlyPlayed = cachedRecents
        }

        let cachedFavorites = HomeCacheStore.loadFavorites()
        if !cachedFavorites.isEmpty {
            favorites = cachedFavorites
        }
    }

    /// Restore cached service categories for a given SID.
    private func restoreCachedServiceContent(for sid: Int) {
        for i in 0..<maxCategoriesPerService {
            let key = ServiceCategoryKey(sid: sid, categoryIndex: i)
            guard serviceCategories[key] == nil else { continue }
            if let cached = HomeCacheStore.loadServiceCategory(sid: sid, categoryIndex: i) {
                serviceCategories[key] = cached.items
                serviceCategoryNames[key] = cached.name
                serviceCategoryCIDs[key] = cached.cid
            }
        }
    }

    // MARK: - Preferences

    func toggleServiceVisibility(sid: Int) {
        HomePreferences.toggleVisibility(sid: sid)
        hiddenSIDs = HomePreferences.hiddenSIDs()
        if hiddenSIDs.contains(sid) {
            loadedSIDs.remove(sid)
        } else {
            if let source = streamingSources.first(where: { $0.sid == sid }),
               serviceCategories[ServiceCategoryKey(sid: sid, categoryIndex: 0)] == nil {
                loadedSIDs.insert(sid)
                startSequentialProbe(for: [source])
            }
        }
    }

    // MARK: - Actions

    func handleCardTap(_ item: BrowseItem, sid: Int, browseAction: (BrowseItem, Int) -> Void) {
        if item.browsable {
            browseAction(item, sid)
        } else {
            playItem(item, sid: sid)
        }
    }

    func playItem(_ item: BrowseItem, sid: Int) {
        let cid = item.cid ?? ""
        Task {
            do {
                try await PlaybackRouter.play(item, sid: sid, cid: cid, service: service, state: state)
            } catch {
                state.showToast(error.localizedDescription, icon: DS.Icons.warning, style: .error)
            }
        }
    }

}
