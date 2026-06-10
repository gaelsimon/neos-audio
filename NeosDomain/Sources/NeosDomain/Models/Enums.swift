import Foundation

public enum PlayState: String, Sendable {
    case play
    case pause
    case stop
}

public enum RepeatMode: String, Sendable {
    case off
    case onAll = "on_all"
    case onOne = "on_one"
}

public enum ShuffleMode: String, Sendable {
    case on
    case off
}

public enum AddCriteria: Int, Sendable {
    case playNow = 1
    case playNext = 2
    case addToEnd = 3
    case replaceAndPlay = 4
}

public enum MediaType: String, Sendable {
    case song
    case station
    case album
    case artist
    case playlist
    case genre
    case container
    case dlnaServer = "dlna_server"
    case heosServer = "heos_server"
    case heosService = "heos_service"
    case musicService = "music_service"
}

public enum OnOff: String, Sendable {
    case on
    case off
}

public enum ConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}
