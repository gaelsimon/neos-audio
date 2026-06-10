import Foundation
import NeosDomain

public struct HEOSResponse: Sendable, Equatable {
    public let command: String
    public let result: HEOSResult
    public let message: [String: String]
    public let payload: JSONValue
    public let rawJSON: JSONValue

    public init(
        command: String,
        result: HEOSResult,
        message: [String: String],
        payload: JSONValue = .null,
        rawJSON: JSONValue = .null
    ) {
        self.command = command
        self.result = result
        self.message = message
        self.payload = payload
        self.rawJSON = rawJSON
    }

    public var isSuccess: Bool {
        result == .success
    }

    public var isUnderProcess: Bool {
        // Per spec 3.2: message is the literal string "command under process"
        // which the message parser stores as a key with empty value
        message.keys.contains("command under process")
    }

    /// Convenience: payload as array of dictionaries.
    public var payloadArray: [[String: JSONValue]] {
        payload.asObjectArray
    }

    /// Convenience: payload as a single dictionary.
    public var payloadDict: [String: JSONValue] {
        payload.asObject ?? [:]
    }
}

public enum HEOSResult: String, Sendable, Equatable {
    case success
    case fail
}

public struct HEOSEvent: Sendable {
    public let command: String
    public let message: [String: String]

    public init(command: String, message: [String: String]) {
        self.command = command
        self.message = message
    }

    public var eventName: String {
        command.replacingOccurrences(of: "event/", with: "")
    }
}

public struct HEOSError: Error, Sendable, CustomStringConvertible, LocalizedError {
    public let errorID: Int
    public let text: String
    public let command: String
    public let message: [String: String]

    public init(errorID: Int, text: String, command: String = "", message: [String: String] = [:]) {
        self.errorID = errorID
        self.text = text
        self.command = command
        self.message = message
    }

    public var description: String {
        "HEOSError(\(errorID)): \(text)"
    }

    public var errorDescription: String? {
        text
    }
}
