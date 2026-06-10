import SwiftUI
import NeosDomain

// MARK: - Playback & Content Fetching

extension BrowseViewModel {

    // MARK: - Playback Actions

    func playContainer() {
        guard let pid = state.selectedPlayerID else {
            state.showNoPlayerToast()
            return
        }
        guard let last = browseStack.last, let cid = last.cid else { return }
        let sid = last.sid
        Task {
            do {
                try await service.addToQueue(pid: pid, sid: sid, cid: cid, mid: nil, criteria: .replaceAndPlay)
                state.showToast("Playing all", icon: DS.Icons.playing, style: .success)
            } catch {
                state.showToast(error.localizedDescription, icon: DS.Icons.warning, style: .error)
            }
        }
    }

    func selectInput(_ item: BrowseItem) {
        guard let pid = state.selectedPlayerID else {
            state.showNoPlayerToast()
            return
        }
        guard let input = item.mid ?? item.cid else {
            state.showToast("Input not available", icon: DS.Icons.warning, style: .error)
            return
        }
        Task {
            do {
                try await service.playInput(pid: pid, input: input)
                state.showToast("Switched to \(item.name)", icon: DS.Icons.success, style: .success)
            } catch {
                state.showToast(error.localizedDescription, icon: DS.Icons.warning, style: .error)
            }
        }
    }

    func addContainerToQueue() {
        guard let pid = state.selectedPlayerID else {
            state.showNoPlayerToast()
            return
        }
        guard let last = browseStack.last, let cid = last.cid else { return }
        let sid = last.sid
        Task {
            do {
                try await service.addToQueue(pid: pid, sid: sid, cid: cid, mid: nil, criteria: .addToEnd)
                state.showToast("Added to queue", icon: DS.Icons.addedToQueue, style: .success)
            } catch {
                state.showToast(error.localizedDescription, icon: DS.Icons.warning, style: .error)
            }
        }
    }

    // MARK: - Content Fetching

    func loadSources() {
        isLoading = true
        let requestID = beginBrowseRequest(cancelCurrent: false)
        Task {
            do {
                let sources = try await fetchMusicSources()
                guard browseTracker.isCurrent(requestID) else { return }
                state.musicSources = sources
            } catch {
                guard browseTracker.isCurrent(requestID) else { return }
                state.error = .generic(error.localizedDescription)
            }
            guard browseTracker.isCurrent(requestID) else { return }
            isLoading = false
        }
    }

    func loadMore() {
        guard !isLoadingMore, !isLoading, hasMore else { return }
        guard let last = browseStack.last else { return }
        guard last.cid != nil || searchContext != nil else { return }
        isLoadingMore = true
        let range = pagination.nextRange
        let requestID = browseTracker.next()
        Task {
            do {
                let result: BrowseResult
                if let ctx = searchContext, last.cid == nil {
                    result = try await service.search(
                        sid: last.sid, query: ctx.query, scid: ctx.scid,
                        range: range
                    )
                } else if let cid = last.cid {
                    result = try await fetchContainer(last.sid, cid, range)
                } else {
                    return
                }
                guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
                let newItems = pagination.recordPage(result.items, serverCount: result.count)
                items.append(contentsOf: newItems)
                state.cacheImageURLs(from: newItems)
            } catch {
                guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
                browseLogger.debug("Load more failed (existing items preserved): \(error.localizedDescription)")
            }
            guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingMore = false
        }
    }

    func playItem(_ item: BrowseItem) {
        let sid = item.sid ?? browseStack.last?.sid ?? 0
        let cid = item.cid ?? browseStack.last?.cid ?? ""
        playingItemID = item.id
        Task {
            do {
                try await PlaybackRouter.play(item, sid: sid, cid: cid, service: service, state: state)
            } catch {
                state.showToast(error.localizedDescription, icon: DS.Icons.warning, style: .error)
            }
            playingItemID = nil
        }
    }

    func addToQueue(_ item: BrowseItem, criteria: AddCriteria = .addToEnd) {
        guard let pid = state.selectedPlayerID else {
            state.showNoPlayerToast()
            return
        }
        let sid = item.sid ?? browseStack.last?.sid ?? 0
        let cid = item.cid ?? browseStack.last?.cid ?? ""
        addingToQueueItemID = item.id
        Task {
            do {
                try await service.addToQueue(pid: pid, sid: sid, cid: cid, mid: item.mid, criteria: criteria)
                let message = criteria == .playNext ? "Playing next" : "Added to queue"
                state.showToast(message, icon: DS.Icons.addedToQueue, style: .success)
            } catch {
                state.showToast(error.localizedDescription, icon: DS.Icons.warning, style: .error)
            }
            addingToQueueItemID = nil
        }
    }

    /// Fetch root content for a source (no stack mutation; stack is set by caller).
    func fetchBrowseRoot(_ source: MusicSource) {
        let requestID = beginBrowseRequest()
        isLoading = true
        errorMessage = nil
        items = []
        pagination.reset()
        loadServiceCapabilitiesIfNeeded(sid: source.sid)
        browseTask.replace(with: Task {
            do {
                let result = try await fetchSource(source.sid)
                guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
                pagination.recordInitialPage(result.items, serverCount: nil)
                items = result.items
                browseOptions = result.options
                state.cacheImageURLs(from: result.items)

                #if DEBUG
                browseLogger.debug("Browse SID \(source.sid) (\(source.name)): \(result.items.count) items")
                for item in result.items {
                    let sid = item.sid?.description ?? "nil"
                    let cid = item.cid ?? "nil"
                    let mid = item.mid ?? "nil"
                    browseLogger.debug(
                        "  [\(item.name)] type=\(item.type.rawValue) sid=\(sid) cid=\(cid) mid=\(mid) browsable=\(item.browsable) playable=\(item.playable)"
                    )
                }
                #endif
            } catch {
                guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoading = false
        })
    }

    func fetchCurrentBreadcrumb() {
        guard let last = browseStack.last else { return }
        let requestID = beginBrowseRequest()
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        items = []
        pagination.reset()
        browseTask.replace(with: Task {
            do {
                if let ctx = searchContext, last.cid == nil, browseStack.count >= 2 {
                    let result = try await service.search(
                        sid: last.sid, query: ctx.query, scid: ctx.scid,
                        range: pagination.firstRange
                    )
                    guard applyBrowseResult(result, requestID: requestID, serverCount: result.count) else { return }
                } else if let cid = last.cid {
                    let result = try await fetchContainer(last.sid, cid, pagination.firstRange)
                    guard applyBrowseResult(result, requestID: requestID, serverCount: result.count) else { return }
                } else {
                    let result = try await fetchSource(last.sid)
                    guard applyBrowseResult(result, requestID: requestID, serverCount: nil) else { return }
                }
            } catch {
                guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoading = false
        })
    }

    /// Apply a browse result to the current view state. Returns false if the request was stale or cancelled.
    @discardableResult
    private func applyBrowseResult(_ result: BrowseResult, requestID: Int, serverCount: Int?) -> Bool {
        guard browseTracker.isCurrent(requestID), !Task.isCancelled else { return false }
        pagination.recordInitialPage(result.items, serverCount: serverCount)
        items = result.items
        browseOptions = result.options
        state.cacheImageURLs(from: result.items)
        return true
    }

    func beginBrowseRequest(cancelCurrent: Bool = true) -> Int {
        if cancelCurrent {
            browseTask.cancel()
        }
        return browseTracker.next()
    }

    // MARK: - Service Options

    func executeServiceOption(_ option: ServiceOption, for item: BrowseItem) {
        let sid = item.sid ?? browseStack.last?.sid ?? 0
        Task {
            do {
                var params: [String: String] = [:]
                if option.id == ServiceOption.removeFromFavoritesID {
                    if let mid = item.mid {
                        params["mid"] = mid
                    }
                }
                if option.id == ServiceOption.addToFavoritesID {
                    if let mid = item.mid {
                        params["mid"] = mid
                    }
                    params["name"] = item.name
                }
                try await service.setServiceOption(sid: sid, option: option.id, params: params)
                state.showToast(option.name, icon: DS.Icons.success, style: .success)
                if option.id == ServiceOption.removeFromFavoritesID, isFavoritesSource {
                    fetchCurrentBreadcrumb()
                }
            } catch {
                state.showToast("Failed: \(option.name)", icon: DS.Icons.warning, style: .error)
            }
        }
    }

    func addFavorite(name: String, url: String) async throws {
        try await service.setServiceOption(
            sid: HEOSConstants.tuneInSID,
            option: ServiceOption.addToFavoritesID,
            params: ["mid": url, "name": name]
        )
        state.showToast("Added \(name)", icon: DS.Icons.success, style: .success)
        fetchCurrentBreadcrumb()
    }

    /// Lazily load service capabilities (search criteria) for a SID if not already cached.
    /// Runs in a detached task so it doesn't block the browse fetch.
    func loadServiceCapabilitiesIfNeeded(sid: Int) {
        guard state.serviceCapabilities[sid] == nil else { return }
        Task {
            do {
                let criteria = try await service.getSearchCriteria(sid: sid)
                guard !criteria.isEmpty else { return }
                state.searchCriteria[sid] = criteria
                state.setServiceCapabilities(sid: sid, capabilities: ServiceCapabilities(from: criteria))
            } catch {
                // Non-fatal; capabilities just won't be available for this service
            }
        }
    }
}
