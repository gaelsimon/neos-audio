import Foundation

// MARK: - Errors

public enum UPnPError: Error, Sendable, LocalizedError, Equatable {
    case httpError(statusCode: Int)
    case soapFault(code: Int, description: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .httpError(let statusCode):
            "UPnP HTTP error: status \(statusCode)"
        case .soapFault(let code, let description):
            "UPnP SOAP fault \(code): \(description)"
        case .invalidResponse:
            "UPnP: invalid or unparseable response"
        }
    }
}

// MARK: - Position Info

public struct PositionInfo: Sendable, Equatable {
    public let track: Int
    public let trackDuration: String   // "H:MM:SS" from device
    public let relTime: String         // "H:MM:SS" from device
    public let trackURI: String?
    public let trackMetaData: String?

    /// Duration as seconds, parsed from `trackDuration`.
    public var duration: TimeInterval? {
        UPnPTimeFormat.toSeconds(trackDuration)
    }

    /// Current position as seconds, parsed from `relTime`.
    public var position: TimeInterval? {
        UPnPTimeFormat.toSeconds(relTime)
    }

    /// Duration in milliseconds for bridging to AppState (which uses Int ms).
    public var durationMillis: Int? {
        duration.map { Int($0 * 1000) }
    }

    /// Position in milliseconds for bridging to AppState (which uses Int ms).
    public var positionMillis: Int? {
        position.map { Int($0 * 1000) }
    }

    public init(
        track: Int,
        trackDuration: String,
        relTime: String,
        trackURI: String? = nil,
        trackMetaData: String? = nil
    ) {
        self.track = track
        self.trackDuration = trackDuration
        self.relTime = relTime
        self.trackURI = trackURI
        self.trackMetaData = trackMetaData
    }
}

// MARK: - Time Format Conversion

/// Bidirectional conversion between `H:MM:SS` UPnP time strings and `TimeInterval` (seconds).
public enum UPnPTimeFormat {

    /// Parse "H:MM:SS" or "HH:MM:SS" into seconds. Returns nil for invalid/non-implemented values.
    public static func toSeconds(_ timeString: String) -> TimeInterval? {
        let trimmed = timeString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "NOT_IMPLEMENTED" else { return nil }

        let parts = trimmed.split(separator: ":")
        guard parts.count == 3,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              let seconds = Int(parts[2]) else {
            return nil
        }

        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    /// Convert seconds to "H:MM:SS" format for UPnP Seek targets.
    public static func fromSeconds(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}
