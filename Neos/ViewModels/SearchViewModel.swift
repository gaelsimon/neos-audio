import Foundation
import NeosDomain
import os

struct ServiceCriteriaKey: Hashable {
    let sid: Int
    let scid: Int
}

enum SearchOverlayPhase: Equatable {
    case inactive
    case active
    case suspended(originHistoryIndex: Int)
}

@Observable
@MainActor
final class SearchViewModel {
    let service: any AudioService
    private let state: AppState
    private let logger = Logger(subsystem: "com.galela.neos", category: "Search")

    // MARK: - Search State

    /// Raw results keyed by (sid, scid) for each service+criteria combination
    var serviceResults: [ServiceCriteriaKey: [BrowseItem]] = [:]
    /// Which services are still loading
    var loadingServiceSIDs: Set<Int> = []
    /// Lifecycle phase of the search overlay
    var overlayPhase: SearchOverlayPhase = .inactive
    /// Categories expanded via "More" -- shows all fetched items instead of preview
    var expandedCategories: Set<ServiceCriteriaKey> = []
    /// Categories currently fetching more results
    var loadingMoreCategories: Set<ServiceCriteriaKey> = []

    /// Sub-sources discovered by browsing into heos_server parents (e.g. DLNA servers
    /// under "Local Music"). Keyed by sub-source SID.
    private(set) var discoveredSubSources: [Int: MusicSource] = [:]

    // MARK: - Filter State

    /// nil means "All" categories
    var selectedCategoryFilter: Int?
    /// nil means "All Services"
    var selectedServiceFilter: Int?

    // MARK: - History

    var recentQueries: [String] = SearchHistoryStore.recentQueries()

    func clearHistory() {
        SearchHistoryStore.clearAll()
        recentQueries = []
    }

    // MARK: - Search Execution

    var isSearching = false
    var query = ""
    private let searchTask = CancellableTaskHandle()
    private let searchTracker = RequestTracker()
    let previewCount = 5

    init(service: any AudioService, state: AppState) {
        self.service = service
        self.state = state
    }

    // MARK: - Overlay Lifecycle

    var isOverlayVisible: Bool { overlayPhase == .active }

    var hasSuspendedSearch: Bool {
        if case .suspended = overlayPhase { return true }
        return false
    }

    func activateOverlay() {
        overlayPhase = .active
    }

    func dismissOverlay() {
        overlayPhase = .inactive
    }

    func suspendForNavigation(originHistoryIndex: Int) {
        guard overlayPhase == .active else { return }
        overlayPhase = .suspended(originHistoryIndex: originHistoryIndex)
    }

    @discardableResult
    func tryRestore(atHistoryIndex index: Int) -> Bool {
        guard case .suspended(let originIndex) = overlayPhase,
              originIndex == index,
              !serviceResults.isEmpty else {
            return false
        }
        overlayPhase = .active
        return true
    }

    // MARK: - Computed Properties

    /// Top-level searchable services (streaming + local music servers via HEOS, excludes library SIDs and hidden)
    var searchableServices: [MusicSource] {
        let hidden = HomePreferences.hiddenSIDs()
        let searchableTypes: Set<String> = ["music_service", "heos_server"]
        return state.musicSources.filter {
            !HEOSConstants.librarySIDs.contains($0.sid)
                && !hidden.contains($0.sid)
                && $0.available
                && searchableTypes.contains($0.type)
                && !$0.isInputSource
        }
    }

    /// All services that can actually be searched: only those with loaded search criteria.
    /// Parents without criteria (e.g. "Local Music") are excluded; their sub-sources appear instead.
    /// Sorted: top-level first, then discovered sub-sources by SID for stable chip ordering.
    var allSearchableServices: [MusicSource] {
        var result = searchableServices.filter { state.searchCriteria[$0.sid] != nil }
        let sortedSubs = discoveredSubSources.values
            .filter { state.searchCriteria[$0.sid] != nil }
            .sorted { $0.sid < $1.sid }
        result.append(contentsOf: sortedSubs)
        return result
    }

    /// Resolve a SID to its MusicSource; checks both top-level sources and discovered sub-sources.
    func musicSource(for sid: Int) -> MusicSource? {
        state.musicSources.first { $0.sid == sid } ?? discoveredSubSources[sid]
    }

    /// Cached active scids and corresponding criteria list; invalidated when serviceResults
    /// or state.searchCriteria change in a way that affects active scids.
    @ObservationIgnored private var cachedCriteriaNames: [(scid: Int, name: String)] = []
    @ObservationIgnored private var cachedCriteriaScids: Set<Int> = []

    /// Criteria that have at least one non-empty result in the current search, deduplicated by scid
    var allCriteriaNames: [(scid: Int, name: String)] {
        let activeScids = Set(
            serviceResults.filter { !$0.value.isEmpty }.map(\.key.scid)
        )
        if activeScids == cachedCriteriaScids, !cachedCriteriaNames.isEmpty {
            return cachedCriteriaNames
        }
        var seen = Set<Int>()
        var result: [(scid: Int, name: String)] = []
        for criteria in state.searchCriteria.values {
            for criterion in criteria {
                if activeScids.contains(criterion.scid) && !seen.contains(criterion.scid) {
                    seen.insert(criterion.scid)
                    result.append((scid: criterion.scid, name: criterion.name))
                }
            }
        }
        let sorted = result.sorted { $0.scid < $1.scid }
        cachedCriteriaScids = activeScids
        cachedCriteriaNames = sorted
        return sorted
    }

    /// SIDs that have results or are loading, ordered by source list position.
    var filteredServiceSIDs: [Int] {
        let resultSIDs = Set(serviceResults.keys.map(\.sid))
        let activeSIDs = resultSIDs.union(loadingServiceSIDs)

        if let selected = selectedServiceFilter {
            return activeSIDs.contains(selected) ? [selected] : []
        }

        // Stable order: top-level services first, then discovered sub-sources
        return allSearchableServices.map(\.sid).filter { activeSIDs.contains($0) }
    }

    /// For a given SID, returns criteria+items pairs matching current filters.
    /// "Track" is always sorted to the top.
    func filteredResults(for sid: Int) -> [(criteria: SearchCriteria, items: [BrowseItem])] {
        guard let criteria = state.searchCriteria[sid] else { return [] }

        var results: [(criteria: SearchCriteria, items: [BrowseItem])] = []
        for criterion in criteria {
            if let filter = selectedCategoryFilter, filter != criterion.scid {
                continue
            }
            let key = ServiceCriteriaKey(sid: sid, scid: criterion.scid)
            guard let items = serviceResults[key], !items.isEmpty else { continue }
            let displayItems = expandedCategories.contains(key)
                ? items
                : Array(items.prefix(previewCount))
            results.append((criteria: criterion, items: displayItems))
        }
        results.sort { lhs, _ in lhs.criteria.name.lowercased().contains("track") }
        return results
    }

    // MARK: - Query Handling

    func onQueryChanged(_ newQuery: String) {
        query = newQuery

        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Soft clear: reset results but keep filters for next search
            searchTask.cancel()
            _ = searchTracker.next()
            isSearching = false
            serviceResults = [:]
            expandedCategories = []
            loadingMoreCategories = []
            if overlayPhase == .active {
                overlayPhase = .inactive
            }
            return
        }

        activateOverlay()
        isSearching = true
        searchTask.replace(with: Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await executeSearch(query: trimmed)
        })
    }

    func clearSearch() {
        searchTask.cancel()
        _ = searchTracker.next()
        query = ""
        overlayPhase = .inactive
        isSearching = false
        serviceResults = [:]
        expandedCategories = []
        loadingMoreCategories = []
        selectedCategoryFilter = nil
        selectedServiceFilter = nil
    }

    // MARK: - Search Execution

    private func executeSearch(query: String) async {
        SearchHistoryStore.addQuery(query)
        recentQueries = SearchHistoryStore.recentQueries()
        let requestID = searchTracker.next()

        isSearching = true
        // Keep old serviceResults as shimmer layout template; don't clear.
        expandedCategories = []
        loadingMoreCategories = []
        loadingServiceSIDs = []

        await loadMissingSearchCriteria()
        guard searchTracker.isCurrent(requestID) else { return }

        // Build searchable set from state.searchCriteria; safe because
        // loadMissingSearchCriteria awaits fully before returning.
        // Includes both top-level services and discovered sub-sources.
        // When a service filter is active, only search that specific service.
        let allSIDs = Set(allSearchableServices.map(\.sid))
        let searchableSIDs: Set<Int>
        if let filteredSID = selectedServiceFilter {
            searchableSIDs = allSIDs.intersection([filteredSID])
        } else {
            searchableSIDs = allSIDs
        }
        let searchable = state.searchCriteria.filter { searchableSIDs.contains($0.key) && !$0.value.isEmpty }
        for sid in searchable.keys {
            loadingServiceSIDs.insert(sid)
        }

        // Search everything sequentially; one command at a time. The HEOS
        // device processes browse/search commands single-threaded; concurrent
        // dispatch (even gated) causes "command under process" responses and
        // unmatched response misrouting. Results stream to the UI after each
        // service completes all its criteria.
        for (sid, criteria) in searchable {
            guard searchTracker.isCurrent(requestID) else { return }
            await searchService(sid: sid, criteria: criteria, query: query, requestID: requestID)
        }

        guard searchTracker.isCurrent(requestID) else { return }

        // Remove results from services that weren't part of this search
        let searchedSIDs = Set(searchable.keys)
        for key in Array(serviceResults.keys) where !searchedSIDs.contains(key.sid) {
            serviceResults.removeValue(forKey: key)
        }

        loadingServiceSIDs = []
        isSearching = false
    }

    /// Searches a single service across all its criteria, collecting batch results
    /// and updating `serviceResults` and `loadingServiceSIDs` when complete.
    private func searchService(
        sid: Int,
        criteria: [SearchCriteria],
        query: String,
        requestID: Int
    ) async {
        var batchResults: [(Int, [BrowseItem])] = []
        for criterion in criteria {
            guard searchTracker.isCurrent(requestID) else { return }
            do {
                let result = try await service.search(
                    sid: sid, query: query, scid: criterion.scid,
                    range: 0...(previewCount - 1)
                )
                batchResults.append((criterion.scid, result.items))
            } catch {
                // Non-fatal; skip this criteria for this search, retry next time
            }
        }

        guard searchTracker.isCurrent(requestID) else { return }

        // Remove stale categories for this SID before writing fresh ones
        let newScids = Set(batchResults.map(\.0))
        for key in Array(serviceResults.keys)
            where key.sid == sid && !newScids.contains(key.scid) {
            serviceResults.removeValue(forKey: key)
        }

        for (scid, items) in batchResults {
            let key = ServiceCriteriaKey(sid: sid, scid: scid)
            serviceResults[key] = items
        }
        loadingServiceSIDs.remove(sid)
    }

    // MARK: - Criteria Loading

    /// Returns the set of SIDs that were freshly loaded.
    @discardableResult
    private func loadMissingSearchCriteria() async -> Set<Int> {
        let topLevel = searchableServices.filter { state.searchCriteria[$0.sid] == nil }
        let subLevel = discoveredSubSources.values.filter { state.searchCriteria[$0.sid] == nil }
        let allSources = topLevel + subLevel
        guard !allSources.isEmpty else { return [] }

        logger.info("Loading search criteria for \(allSources.map { "\($0.name) (sid=\($0.sid), type=\($0.type))" }.joined(separator: ", "))")

        var loadedSIDs = Set<Int>()
        var parentsToBrowse: [MusicSource] = []

        await withTaskGroup(of: (Int, String, String, [SearchCriteria])?.self) { group in
            for source in allSources {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    do {
                        let criteria = try await self.service.getSearchCriteria(sid: source.sid)
                        return (source.sid, source.name, source.type, criteria)
                    } catch {
                        self.logger.warning("getSearchCriteria failed for \(source.name) (sid=\(source.sid)): \(error)")
                        return nil
                    }
                }
            }
            let topLevelSIDs = Set(topLevel.map(\.sid))
            for await result in group {
                guard let (sid, name, type, criteria) = result else { continue }
                if criteria.isEmpty {
                    logger.info("No search criteria for \(name) (sid=\(sid)); search not supported")
                    // Only browse into top-level heos_server parents for sub-sources,
                    // not into already-discovered sub-sources (avoids recursive discovery)
                    if type == "heos_server",
                       topLevelSIDs.contains(sid),
                       let source = topLevel.first(where: { $0.sid == sid }) {
                        parentsToBrowse.append(source)
                    }
                } else {
                    logger.info("Search criteria for \(name) (sid=\(sid)): \(criteria.map(\.name).joined(separator: ", "))")
                    state.searchCriteria[sid] = criteria
                    state.setServiceCapabilities(sid: sid, capabilities: ServiceCapabilities(from: criteria))
                    loadedSIDs.insert(sid)
                }
            }
        }

        for parent in parentsToBrowse {
            let subSourceSIDs = await discoverSubSources(for: parent)
            loadedSIDs.formUnion(subSourceSIDs)
        }

        return loadedSIDs
    }

    /// Browses a parent heos_server source to find sub-sources, then checks each
    /// for search criteria. Registers searchable sub-sources in `discoveredSubSources`.
    private func discoverSubSources(for parent: MusicSource) async -> Set<Int> {
        logger.info("Browsing \(parent.name) (sid=\(parent.sid)) for searchable sub-sources")

        let items: [BrowseItem]
        do {
            let result = try await service.browseSource(sid: parent.sid)
            items = result.items
        } catch {
            logger.warning("Failed to browse \(parent.name) (sid=\(parent.sid)): \(error)")
            return []
        }

        let subSourceItems = items.filter { $0.sid != nil }
        guard !subSourceItems.isEmpty else {
            logger.info("No sub-sources found under \(parent.name)")
            return []
        }

        logger.info("Found \(subSourceItems.count) sub-source(s) under \(parent.name): \(subSourceItems.map { "\($0.name) (sid=\($0.sid ?? 0))" }.joined(separator: ", "))")

        var loadedSIDs = Set<Int>()
        for item in subSourceItems {
            guard let sid = item.sid, state.searchCriteria[sid] == nil else { continue }
            do {
                let criteria = try await service.getSearchCriteria(sid: sid)
                if criteria.isEmpty {
                    logger.info("No search criteria for sub-source \(item.name) (sid=\(sid))")
                    continue
                }
                logger.info("Search criteria for sub-source \(item.name) (sid=\(sid)): \(criteria.map(\.name).joined(separator: ", "))")
                state.searchCriteria[sid] = criteria
                state.setServiceCapabilities(sid: sid, capabilities: ServiceCapabilities(from: criteria))
                discoveredSubSources[sid] = MusicSource(
                    sid: sid,
                    name: item.name,
                    imageURL: item.imageURL,
                    type: "heos_server"
                )
                loadedSIDs.insert(sid)
            } catch {
                logger.warning("getSearchCriteria failed for sub-source \(item.name) (sid=\(sid)): \(error)")
            }
        }
        return loadedSIDs
    }

    // MARK: - Filter Actions

    func selectCategoryFilter(_ scid: Int?) {
        if selectedCategoryFilter == scid {
            selectedCategoryFilter = nil
        } else {
            selectedCategoryFilter = scid
        }
    }

    func selectServiceFilter(_ sid: Int?) {
        if selectedServiceFilter == sid {
            selectedServiceFilter = nil
        } else {
            selectedServiceFilter = sid
        }
    }
}
