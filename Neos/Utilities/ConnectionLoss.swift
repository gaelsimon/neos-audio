import HEOSKit

/// Tells a request cut off by the connection going away from one the speaker answered with an error.
enum ConnectionLoss {
    static func matches(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        // A timeout means a slow service, as swift-heos's search treats it, not a dropped speaker.
        if let transportError = error as? TransportError { return transportError != .timeout }
        if case .notConnected? = error as? HEOSServiceError { return true }
        return false
    }
}
