import HEOSKit

/// Tells a request cut off by the connection going away from one the speaker answered with an error.
enum ConnectionLoss {
    static func matches(_ error: Error) -> Bool {
        if error is TransportError || error is CancellationError { return true }
        if case .notConnected? = error as? HEOSServiceError { return true }
        return false
    }
}
