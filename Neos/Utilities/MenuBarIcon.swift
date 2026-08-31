import Foundation
import NeosDomain

/// Status item glyph: playing, connected and idle, or not connected.
func menuBarIconName(connectionState: ConnectionState, isPlaying: Bool) -> String {
    guard connectionState == .connected else { return DS.Icons.speaker }
    return isPlaying ? DS.Icons.speakerActive : DS.Icons.speakerFill
}
