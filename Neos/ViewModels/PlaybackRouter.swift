import Foundation
import os
import NeosDomain

private let playbackLogger = Logger(subsystem: "com.galela.neos", category: "playback")

/// Single source of truth for station-vs-track play routing.
/// Stations use HEOS play_stream (4.4.7); tracks use add_to_queue with playNow (4.4.12).
/// TuneIn custom URL stations (uXX mids) are played via TuneIn (sid=3) with the
/// TuneIn favorites container cid so the device handles stream resolution natively.
enum PlaybackRouter {
    @MainActor
    static func play(_ item: BrowseItem, sid: Int, cid: String, service: any AudioService, state: AppState) async throws {
        guard let pid = state.selectedPlayerID else {
            state.showNoPlayerToast()
            return
        }
        if item.mid == nil {
            playbackLogger.warning("Playing item with nil mid; using container-based playback: \(item.name)")
        }
        state.isLoadingTrack = true
        do {
            if item.type == .station, let mid = item.mid, mid.hasPrefix("http://") || mid.hasPrefix("https://") {
                state.pendingStreamContext = .init(
                    pid: pid, stationName: item.name,
                    browseMID: mid, imageURL: item.imageURL, streamURL: mid
                )
                try await service.playURL(pid: pid, url: mid)
            } else if item.type == .station, let mid = item.mid, isTuneInCustomURL(mid) {
                try await playViaTuneIn(
                    pid: pid, mid: mid, name: item.name,
                    imageURL: item.imageURL, service: service, state: state
                )
            } else if item.type == .station, let mid = item.mid {
                try await service.playStation(pid: pid, sid: sid, cid: cid, mid: mid, name: item.name)
            } else {
                try await service.addToQueue(pid: pid, sid: sid, cid: cid, mid: item.mid, criteria: .playNow)
            }
        } catch {
            state.isLoadingTrack = false
            state.pendingStreamContext = nil
            throw error
        }
        state.showToast("Now playing", icon: DS.Icons.playing, style: .success)
    }

    // MARK: - TuneIn Custom URL Resolution

    /// TuneIn custom URL mids match the pattern "u" followed by digits (e.g. "u32", "u48").
    private static func isTuneInCustomURL(_ mid: String) -> Bool {
        mid.hasPrefix("u") && mid.dropFirst().allSatisfy(\.isNumber) && mid.count > 1
    }

    /// Plays a TuneIn custom URL station (uXX mid).
    /// When the item name is a stream URL, uses the play_stream url= form (HEOS 4.4.10)
    /// which handles URL playback natively. Otherwise routes through TuneIn (sid=3)
    /// with the TuneIn favorites container cid so the device resolves the uXX mid.
    @MainActor
    private static func playViaTuneIn(
        pid: Int, mid: String, name: String, imageURL: String,
        service: any AudioService, state: AppState
    ) async throws {
        // When name is a stream URL, use play_stream url= form (4.4.10).
        if name.hasPrefix("http://") || name.hasPrefix("https://") {
            state.pendingStreamContext = .init(
                pid: pid, stationName: nil,
                browseMID: mid, imageURL: imageURL, streamURL: name
            )
            try await service.playURL(pid: pid, url: name)
            return
        }

        // Browse TuneIn root to find the Favorites container cid
        let root = try await service.browseSource(sid: HEOSConstants.tuneInSID)
        guard let favCID = root.items.first(where: { $0.name == "Favorites" })?.cid else {
            throw PlaybackError.cannotResolveStreamURL(mid)
        }
        try await service.playStation(pid: pid, sid: HEOSConstants.tuneInSID, cid: favCID, mid: mid, name: name)
    }
}

enum PlaybackError: LocalizedError {
    case cannotResolveStreamURL(String)

    var errorDescription: String? {
        switch self {
        case .cannotResolveStreamURL(let mid):
            return "Cannot resolve stream URL for \(mid)"
        }
    }
}
