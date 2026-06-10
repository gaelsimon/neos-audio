import NeosDomain

/// Shared utility for loading HEOS play history (tracks and/or stations).
/// Used by HomeViewModel and QueuePanelViewModel to avoid duplicating browse logic.
enum HistoryLoader {
    struct Result {
        var tracks: [BrowseItem] = []
        var stations: [BrowseItem] = []
    }

    /// Browse the HEOS history source to fetch recent tracks and optionally stations.
    /// - Parameters:
    ///   - service: The audio service to browse through.
    ///   - trackLimit: Maximum number of track items to fetch.
    ///   - stationLimit: Maximum number of station items to fetch. Pass nil to skip stations.
    static func load(
        service: any AudioService,
        trackLimit: Int,
        stationLimit: Int? = nil
    ) async throws -> Result {
        let topLevel = try await service.getHistory()
        try Task.checkCancellation()

        var result = Result()

        let tracksContainer = topLevel.items.first {
            $0.name.lowercased().contains("track") && $0.browsable
        }
        if let tracksContainer, let cid = tracksContainer.cid {
            let browse = try await service.browseContainer(
                sid: HEOSConstants.historySID, cid: cid, range: 0...(trackLimit - 1)
            )
            try Task.checkCancellation()
            result.tracks = browse.items
        } else {
            // Fallback: use playable top-level items directly
            result.tracks = Array(
                topLevel.items.filter { $0.playable || !$0.browsable }.prefix(trackLimit)
            )
        }

        if let stationLimit {
            let stationsContainer = topLevel.items.first {
                $0.name.lowercased().contains("station") && $0.browsable
            }
            if let stationsContainer, let cid = stationsContainer.cid {
                let browse = try await service.browseContainer(
                    sid: HEOSConstants.historySID, cid: cid, range: 0...(stationLimit - 1)
                )
                try Task.checkCancellation()
                result.stations = browse.items
            }
        }

        return result
    }
}
