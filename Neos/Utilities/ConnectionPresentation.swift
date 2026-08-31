import Foundation
import NeosDomain

/// What the main window shows: an established session reconnects in place, banner instead of splash.
struct ConnectionPresentation {
    let showsContent: Bool
    let showsSplash: Bool
    let showsReconnectingBanner: Bool
    let showsDiscovery: Bool

    init(connectionState: ConnectionState, hasEstablishedSession: Bool, isHoldingConnectedSplash: Bool) {
        let isConnected = connectionState == .connected
        let isBusy = connectionState == .connecting || connectionState == .reconnecting

        showsContent = isConnected || hasEstablishedSession
        showsSplash = isHoldingConnectedSplash || (isBusy && !hasEstablishedSession)
        showsReconnectingBanner = hasEstablishedSession && !isConnected
        showsDiscovery = !showsContent && !showsSplash
    }
}
