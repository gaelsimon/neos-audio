import Foundation
import NeosDomain

extension NowPlayingMedia {
    /// The line to show as the title. Radio streams often carry no track name, and a
    /// playing station is not "Not Playing": it is the station.
    var displayedTitle: String {
        if !song.isEmpty { return song.displayTitle }
        if let station, !station.isEmpty { return station.displayTitle }
        return "Not Playing"
    }

    /// The station name, unless it is already the title.
    var displayedStation: String? {
        guard let station, !station.isEmpty, !song.isEmpty else { return nil }
        return station.displayTitle
    }
}
