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
    case suspended(originToken: Int)
    /// Closed by Back on that entry, so Forward can reopen it.
    case closedByBack(token: Int)
}

@Observable
@MainActor
final class SearchViewModel {
    let service: any AudioService
    private let state: AppState
    private let serverPreferences: LocalServerPreferences
    private let logger = Logger(subsystem: "com.galela.neos", category: "Search")

    // MARK: - Search State

    /// Raw results keyed by (sid, scid) for each service+criteria combination
    var serviceResults: [ServiceCriteriaKey: [BrowseItem]] = [:]
    /// Which services are still loading
    var loadingServiceSIDs: Set<Int> = []
    /// Categories whose answer to the current query has not arrived yet.
    private(set) var pendingKeys: Set<ServiceCriteriaKey> = []
    /// Services whose every category answered the current query; the others may still show an earlier query's results.
    private var answeredSIDs: Set<Int> = []
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

    /// Keeps the query once it is submitted or one of its results is used, not at every pause in typing.
    func commitQueryToHistory() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        SearchHistoryStore.addQuery(trimmed)
        recentQueries = SearchHistoryStore.recentQueries()
    }

    /// A past query picked from the list runs again and moves to the top.
    func searchAgain(_ pastQuery: String) {
        onQueryChanged(pastQuery)
        commitQueryToHistory()
    }

    func isPending(_ key: ServiceCriteriaKey) -> Bool {
        pendingKeys.contains(key)
    }

    // MARK: - Search Execution

    var isSearching = false
    var query = ""
    private let searchTask = CancellableTaskHandle()
    private let searchTracker = RequestTracker()
    let previewCount = 5

    init(service: any AudioService, state: AppState, serverPreferences: LocalServerPreferences? = nil) {
        self.service = service
        self.state = state
        self.serverPreferences = serverPreferences ?? LocalServerPreferences()
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
        // A suspended search survives ambient dismissals so back-navigation can still restore it.
        guard overlayPhase == .active else { return }
        overlayPhase = .inactive
    }

    func closeForBack(atToken token: Int) {
        guard overlayPhase == .active else { return }
        overlayPhase = .closedByBack(token: token)
    }

    func canReopen(atToken token: Int) -> Bool {
        overlayPhase == .closedByBack(token: token)
    }

    @discardableResult
    func reopen(atToken token: Int) -> Bool {
        guard canReopen(atToken: token) else { return false }
        overlayPhase = .active
        return true
    }

    /// A new page truncates the forward history, and the search closed by Back with it.
    func dropClosedByBack() {
        if case .closedByBack = overlayPhase { overlayPhase = .inactive }
    }

    func suspendForNavigation(originToken: Int) {
        guard overlayPhase == .active else { return }
        overlayPhase = .suspended(originToken: originToken)
    }

    @discardableResult
    func tryRestore(atToken token: Int) -> Bool {
        guard case .suspended(let originToken) = overlayPhase,
              originToken == token,
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
            .filter { state.searchCriteria[$0.sid] != nil && serverPreferences.isSearchable($0.name) }
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

    /// SIDs with something to show under the current filters or still loading, ordered by source list position.
    var filteredServiceSIDs: [Int] {
        let resultSIDs = Set(serviceResults.keys.map(\.sid)).filter { !filteredResults(for: $0).isEmpty }
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
            answeredSIDs = []
            pendingKeys = []
            loadingServiceSIDs = []
            expandedCategories = []
            loadingMoreCategories = []
            // Results are gone, so a suspension could never be restored; it would only
            // keep the back arrow enabled with nothing to go back to.
            overlayPhase = .inactive
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
        answeredSIDs = []
        pendingKeys = []
        loadingServiceSIDs = []
        expandedCategories = []
        loadingMoreCategories = []
        selectedCategoryFilter = nil
        selectedServiceFilter = nil
    }

    // MARK: - Search Execution

    /// Runs the search for `query`. Pass `reusingCache: true` for a filter change
    /// (same query): it only searches target services that have not answered it and
    /// keeps results for services outside the current filter.
    private func executeSearch(query: String, reusingCache: Bool = false) async {
        let requestID = searchTracker.next()

        isSearching = true
        if !reusingCache {
            answeredSIDs = []
        }
        // Keep old serviceResults as the placeholder layout template; don't clear.
        expandedCategories = []
        loadingMoreCategories = []
        loadingServiceSIDs = []
        pendingKeys = []

        await loadMissingSearchCriteria()
        guard isCurrent(requestID) else { return }

        // Target services: the filtered one, or all when no filter is set.
        // Includes top-level services and discovered sub-sources.
        let allSIDs = Set(allSearchableServices.map(\.sid))
        // A filter on a server taken out of search since would match nothing.
        if let filteredSID = selectedServiceFilter, !allSIDs.contains(filteredSID) {
            selectedServiceFilter = nil
        }
        let targetSIDs: Set<Int>
        if let filteredSID = selectedServiceFilter {
            targetSIDs = allSIDs.intersection([filteredSID])
        } else {
            targetSIDs = allSIDs
        }
        var searchable = state.searchCriteria.filter { targetSIDs.contains($0.key) && !$0.value.isEmpty }

        // Filter change: only fetch target services we don't already have.
        if reusingCache {
            searchable = searchable.filter { !answeredSIDs.contains($0.key) }
        }

        let keys = searchOrder(searchable)
        pendingKeys = Set(keys)
        loadingServiceSIDs = Set(keys.map(\.sid))
        await runSearches(keys, query: query, requestID: requestID)

        guard isCurrent(requestID) else { return }

        // Fresh query only: drop results from services not part of this search.
        // A filter change keeps them, so switching back to "All" is instant.
        if !reusingCache {
            let searchedSIDs = Set(searchable.keys)
            for key in Array(serviceResults.keys) where !searchedSIDs.contains(key.sid) {
                serviceResults.removeValue(forKey: key)
            }
        }

        loadingServiceSIDs = []
        pendingKeys = []
        isSearching = false
    }

    /// Local servers first: they answer at once, and the speaker takes only so many searches together.
    func searchOrder(_ searchable: [Int: [SearchCriteria]]) -> [ServiceCriteriaKey] {
        let services = allSearchableServices
        let ordered = services.filter { $0.type == "heos_server" } + services.filter { $0.type != "heos_server" }
        return ordered.flatMap { source in
            (searchable[source.sid] ?? []).map { ServiceCriteriaKey(sid: source.sid, scid: $0.scid) }
        }
    }

    /// Every category at once; each one shows as soon as its answer arrives.
    private func runSearches(_ keys: [ServiceCriteriaKey], query: String, requestID: Int) async {
        let service = service
        let range = 0...(previewCount - 1)
        await withTaskGroup(of: (ServiceCriteriaKey, [BrowseItem]?).self) { group in
            for key in keys {
                group.addTask {
                    let result = try? await service.search(sid: key.sid, query: query, scid: key.scid, range: range)
                    return (key, result?.items)
                }
            }
            for await (key, items) in group {
                guard isCurrent(requestID) else {
                    group.cancelAll()
                    return
                }
                record(items, for: key)
            }
        }
    }

    /// A cancelled search's requests come back empty, so it must stop before it records them as no results.
    private func isCurrent(_ requestID: Int) -> Bool {
        searchTracker.isCurrent(requestID) && !Task.isCancelled
    }

    /// A failed category is left out until the next search asks it again.
    private func record(_ items: [BrowseItem]?, for key: ServiceCriteriaKey) {
        if let items {
            serviceResults[key] = items
        } else {
            serviceResults.removeValue(forKey: key)
        }
        pendingKeys.remove(key)
        guard !pendingKeys.contains(where: { $0.sid == key.sid }) else { return }
        loadingServiceSIDs.remove(key.sid)
        let current = Set(state.searchCriteria[key.sid]?.map(\.scid) ?? [])
        for stale in Array(serviceResults.keys) where stale.sid == key.sid && !current.contains(stale.scid) {
            serviceResults.removeValue(forKey: stale)
        }
        if serviceResults.keys.contains(where: { $0.sid == key.sid }) {
            answeredSIDs.insert(key.sid)
        }
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

        let subSourceItems = items.filter { $0.sid != nil && serverPreferences.isSearchable($0.name) }
        guard !subSourceItems.isEmpty else {
            logger.info("No sub-sources found under \(parent.name)")
            return []
        }

        let names = subSourceItems.map { "\($0.name) (sid=\($0.sid ?? 0))" }.joined(separator: ", ")
        logger.info("Found \(subSourceItems.count) sub-source(s) under \(parent.name): \(names)")

        var loadedSIDs = Set<Int>()
        for item in subSourceItems {
            guard let sid = item.sid else { continue }
            // Opening a server loads its criteria too, and it must still be registered here.
            if let known = state.searchCriteria[sid], !known.isEmpty {
                registerSubSource(item, sid: sid)
                loadedSIDs.insert(sid)
                continue
            }
            do {
                let criteria = try await service.getSearchCriteria(sid: sid)
                if criteria.isEmpty {
                    logger.info("No search criteria for sub-source \(item.name) (sid=\(sid))")
                    continue
                }
                logger.info("Search criteria for sub-source \(item.name) (sid=\(sid)): \(criteria.map(\.name).joined(separator: ", "))")
                state.searchCriteria[sid] = criteria
                state.setServiceCapabilities(sid: sid, capabilities: ServiceCapabilities(from: criteria))
                registerSubSource(item, sid: sid)
                loadedSIDs.insert(sid)
            } catch {
                logger.warning("getSearchCriteria failed for sub-source \(item.name) (sid=\(sid)): \(error)")
            }
        }
        return loadedSIDs
    }

    func registerSubSource(_ item: BrowseItem, sid: Int) {
        discoveredSubSources[sid] = MusicSource(sid: sid, name: item.name, imageURL: item.imageURL, type: "heos_server")
    }
}

// MARK: - Filter Actions

extension SearchViewModel {
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
        // A filter change alters which SIDs executeSearch covers, so re-fetch.
        rerunSearchForCurrentQuery()
    }

    /// Re-runs the search after a filter change (same query, no typing debounce).
    /// No-op when every targeted service already answered the query -- switching is then
    /// a pure display filter handled by `filteredServiceSIDs`.
    private func rerunSearchForCurrentQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, hasUnloadedTargetServices else { return }
        isSearching = true
        searchTask.replace(with: Task {
            guard !Task.isCancelled else { return }
            await executeSearch(query: trimmed, reusingCache: true)
        })
    }

    /// True when the current service filter targets a service that has not answered the current query.
    private var hasUnloadedTargetServices: Bool {
        if let sid = selectedServiceFilter {
            return !answeredSIDs.contains(sid)
        }
        return allSearchableServices.contains { !answeredSIDs.contains($0.sid) }
    }
}
