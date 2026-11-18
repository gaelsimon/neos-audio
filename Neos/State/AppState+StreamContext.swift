import Foundation
import NeosDomain

// MARK: - Stream Context Matching

extension AppState {
    /// Whether this event belongs to the stream the context was captured for.
    /// Station to station switching replays the outgoing stream as a generic "Url Stream"
    /// event too, so the incoming context must not treat it as its own.
    static func isEnrichable(_ media: NowPlayingMedia, by ctx: PlaybackState.StreamPlayContext) -> Bool {
        if let bound = ctx.enrichedDeviceMID {
            return bound == media.mid && (ctx.enrichedQID == nil || ctx.enrichedQID == media.qid)
        }
        if Self.sameStream(media.mid, ctx.streamURL) { return true }
        if media.mid != ctx.previousMID { return true }
        // A raw stream asked for here takes a queue place of its own, which the outgoing one's replay does not.
        if media.isUnnamedStream, let before = ctx.previousQID, let place = media.qid, place != before { return true }
        // Some devices report a placeholder mid for every raw url stream, so the outgoing and
        // incoming stream look identical. Once its replay has gone by, the event is ours.
        return ctx.toleratedTail
    }

    /// Two references to one stream, ignoring the scheme: a device reports the same station
    /// over http on one play and https on the next.
    static func sameStream(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return StreamAddress.withoutScheme(lhs) == StreamAddress.withoutScheme(rhs)
    }
}

// MARK: - Raw Stream Naming

extension AppState {
    /// A "Url Stream" takes the name known when it was played here, and that context is bound to it or dropped.
    func namedByPlayContext(_ media: NowPlayingMedia) -> NowPlayingMedia {
        guard var ctx = playback.pendingStreamContext else { return media }
        guard ctx.pid == selectedPlayerID else {
            playback.pendingStreamContext = nil
            return media
        }
        if streamOnlyMoved(to: media), ctx.enrichedQID == playback.nowPlaying.qid {
            ctx.enrichedQID = media.qid
            playback.pendingStreamContext = ctx
        }
        guard media.isUnnamedStream, Self.isEnrichable(media, by: ctx) else {
            if media.mid != ctx.previousMID {
                // Another stream took over, or a genuinely new track started.
                playback.pendingStreamContext = nil
            } else {
                // Tail event of the track playing at capture; the stream is still starting.
                playback.pendingStreamContext?.toleratedTail = true
            }
            return media
        }
        if !ctx.browseMID.isEmpty, ctx.browseMID != media.mid {
            imageCache.registerStreamAlias(deviceMID: media.mid, browseMID: ctx.browseMID)
        }
        // Bound: further events for this stream keep the name, another stream drops the context.
        playback.pendingStreamContext?.enrichedDeviceMID = media.mid
        playback.pendingStreamContext?.enrichedQID = media.qid
        // A station saved under its address alone is named after that address at once.
        guard let name = [ctx.stationName ?? "", ctx.streamURL].first(where: { !$0.isEmpty }) else { return media }
        return NowPlayingMedia(
            type: media.type, song: media.song, album: media.album, artist: media.artist,
            imageURL: media.imageURL.isEmpty ? ctx.imageURL : media.imageURL,
            albumID: media.albumID, mid: media.mid, qid: media.qid, sid: media.sid,
            station: name
        )
    }

    /// The playing stream sent at another queue place: an entry before it left the queue.
    private func streamOnlyMoved(to media: NowPlayingMedia) -> Bool {
        let current = playback.nowPlaying
        return current.isUnnamedStream && media.isUnnamedStream && current.mid == media.mid
            && current.qid != media.qid && playback.playState == .play
    }

    /// An event for a raw stream carries no name: the one found for this queue entry stays until its address is read again.
    func keepingStreamName(_ media: NowPlayingMedia, startsStream: Bool) -> NowPlayingMedia {
        guard media.isUnnamedStream else {
            playback.trackMetadataIsStale = false
            playback.rawStream = .init()
            return media
        }
        let current = playback.nowPlaying
        let moved = !startsStream && streamOnlyMoved(to: media)
        let continues = !startsStream && current.isUnnamedStream && (current.qid == media.qid || moved)
        if !continues {
            playback.rawStream = .init(doubted: playback.trackMetadata?.streamURL ?? playback.rawStream.address)
        } else if playback.playState == .play {
            playback.rawStream.doubted = nil
        }
        if moved { playback.rawStream.movedAt = Date() }
        playback.trackMetadataIsStale = true
        onTrackMetadataWanted?()
        // While it buffers a speaker gives the bitrate where a station's name goes.
        let sentName = media.station.flatMap { $0.isBitrateLabel ? nil : $0 }
        let keepsName = continues && sentName == nil && playback.rawStream.namedFrom != nil
        if !keepsName { playback.rawStream.namedFrom = nil }
        let placeholder = HEOSConstants.urlStreamTitle
        return NowPlayingMedia(
            type: media.type, song: media.song,
            album: media.album == placeholder ? "" : media.album,
            artist: media.artist == placeholder ? "" : media.artist,
            imageURL: keepsName ? current.imageURL : media.imageURL,
            albumID: media.albumID, mid: media.mid, qid: media.qid, sid: media.sid,
            station: keepsName ? current.station : sentName
        )
    }

    /// Until then the speaker's address is still the one of what played before.
    func rawStreamReportedPlaying() {
        guard playback.nowPlaying.isUnnamedStream else { return }
        playback.rawStream.heardPlay = true
        playback.rawStream.doubted = nil
        playback.trackMetadataIsStale = true
        onTrackMetadataWanted?()
    }

    /// A stream that stops right after changing place had not moved: another one is starting there.
    func rawStreamReportedStopped() {
        let media = playback.nowPlaying
        guard media.isUnnamedStream, let movedAt = playback.rawStream.movedAt,
              Date().timeIntervalSince(movedAt) < Self.streamMoveGrace else { return }
        playback.rawStream = .init(doubted: playback.rawStream.address)
        playback.pendingStreamContext = nil
        playback.trackMetadataIsStale = true
        playback.nowPlaying = NowPlayingMedia(
            type: media.type, song: media.song, album: media.album, artist: media.artist,
            albumID: media.albumID, mid: media.mid, qid: media.qid, sid: media.sid
        )
    }

    /// Measured: the stop of a stream change comes with the event that announces it.
    private static let streamMoveGrace: TimeInterval = 2

    /// Leaving the metadata stale asks for another read.
    func readStreamAddress(_ read: String?) {
        guard let address = read, StreamAddress.isAddress(address) else { return }
        if let doubted = playback.rawStream.doubted, Self.sameStream(address, doubted) { return }
        playback.rawStream.doubted = nil
        playback.trackMetadataIsStale = false
        playback.rawStream.address = address
        nameUnnamedStream()
    }

    /// Names the raw stream that is playing from its address, the one thing a speaker says about it.
    func nameUnnamedStream() {
        let media = playback.nowPlaying
        guard media.isUnnamedStream, let address = playback.rawStream.address else { return }
        if media.station != nil, playback.rawStream.namedFrom == nil {
            guard addressContradictsNameGivenAtPlay(address) else { return }
        }
        let known = imageCache.station(forStream: address)
        if let known, !media.mid.isEmpty, known.browseMID != media.mid {
            imageCache.registerStreamAlias(deviceMID: media.mid, browseMID: known.browseMID)
        } else {
            imageCache.removeStreamAlias(deviceMID: media.mid)
        }
        playback.rawStream.namedFrom = address
        let named = NowPlayingMedia(
            type: media.type, song: media.song, album: media.album, artist: media.artist,
            imageURL: known?.imageURL ?? "",
            albumID: media.albumID, mid: media.mid, qid: media.qid, sid: media.sid,
            station: known?.name ?? address
        )
        if named != media { playback.nowPlaying = named }
    }

    /// True when the address shows the speaker has moved to another stream than the one named at play.
    private func addressContradictsNameGivenAtPlay(_ address: String) -> Bool {
        guard let ctx = playback.pendingStreamContext else { return false }
        if ctx.streamURL.isEmpty {
            // TuneIn resolved the address: learn it, but only from a read made while this stream plays.
            guard playback.rawStream.heardPlay else { return false }
            playback.pendingStreamContext?.streamURL = address
            imageCache.rememberStation(
                .init(name: ctx.stationName, browseMID: ctx.browseMID, imageURL: ctx.imageURL),
                forStream: address
            )
            return false
        }
        guard !Self.sameStream(address, ctx.streamURL) else { return false }
        playback.pendingStreamContext = nil
        return true
    }

    /// A speaker often sends a station with neither a song nor its own name; a row seen for it has the name.
    func withKnownStationName(_ media: NowPlayingMedia) -> NowPlayingMedia {
        guard media.type == .station, media.song.isEmpty, media.station?.isEmpty ?? true,
              let name = imageCache.stationName(for: media) else { return media }
        return NowPlayingMedia(
            type: media.type, song: media.song, album: media.album, artist: media.artist,
            imageURL: media.imageURL, albumID: media.albumID, mid: media.mid,
            qid: media.qid, sid: media.sid, station: name
        )
    }

    func nameUntitledStation() {
        let named = withKnownStationName(playback.nowPlaying)
        if named != playback.nowPlaying { playback.nowPlaying = named }
    }
}
