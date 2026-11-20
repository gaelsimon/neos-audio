import Foundation
import NeosDomain

extension NowPlayingMedia {
    /// The line to show as the title. Radio streams often carry no track name, and a
    /// playing station is not "Not Playing": it is the station.
    var displayedTitle: String {
        if isUnnamedStream { return streamTitle }
        if !song.isEmpty, !hasBitrateForSong { return song.displayTitle }
        if let station, !station.isEmpty { return station.displayTitle }
        return "Not Playing"
    }

    /// The station name, unless it is already the title.
    var displayedStation: String? {
        if isUnnamedStream { return station.flatMap(Self.hostOfAddress) }
        guard let station, !station.isEmpty, !song.isEmpty, station != song, !hasBitrateForSong else { return nil }
        return station.displayTitle
    }

    /// A raw stream, whose `station` then holds the name found for it, or its address.
    var isUnnamedStream: Bool { song == HEOSConstants.urlStreamTitle }

    /// A station plays outside the queue; a raw stream is one of its entries.
    var playsFromQueue: Bool { station == nil || isUnnamedStream }

    /// The lines of the row that stands for what is playing when no queue row does.
    var standaloneRowTitle: String { isUnnamedStream ? displayedTitle : song }
    var standaloneRowSubtitle: String { isUnnamedStream ? displayedStation ?? "" : station ?? artist }

    /// While a station buffers, a speaker gives its bitrate as the song.
    private var hasBitrateForSong: Bool {
        type == .station && song.isBitrateLabel && !(station ?? "").isEmpty
    }

    private var streamTitle: String {
        guard let station, !station.isEmpty else { return "Stream" }
        return StreamAddress.isAddress(station) ? StreamAddress.title(of: station) : station.displayTitle
    }

    private static func hostOfAddress(_ station: String) -> String? {
        StreamAddress.isAddress(station) ? StreamAddress.host(of: station) : nil
    }
}

extension QueueItem {
    /// The entry a raw stream takes in the queue: the speaker's placeholder for a title and no id.
    var isLeftByAStream: Bool { song == HEOSConstants.urlStreamTitle && mid.isEmpty }
}
