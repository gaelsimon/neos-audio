import Foundation

public struct MusicSource: Identifiable, Equatable, Sendable {
    public let sid: Int
    public let name: String
    public let imageURL: String
    public let type: String
    public let available: Bool
    public var serviceUsername: String?

    public var id: Int { sid }

    /// True when the source represents a physical input (AUX, Optical, etc.)
    /// rather than a streaming or network music service.
    public var isInputSource: Bool {
        let lowered = name.lowercased()
        return lowered.contains("aux") || lowered.contains("input")
    }

    public init(
        sid: Int,
        name: String,
        imageURL: String = "",
        type: String = "",
        available: Bool = true,
        serviceUsername: String? = nil
    ) {
        self.sid = sid
        self.name = name
        self.imageURL = imageURL
        self.type = type
        self.available = available
        self.serviceUsername = serviceUsername
    }
}
