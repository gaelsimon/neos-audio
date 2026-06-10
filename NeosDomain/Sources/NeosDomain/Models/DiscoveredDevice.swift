import Foundation

public struct DiscoveredDevice: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let host: String
    public let port: Int
    public let friendlyName: String
    public let modelName: String
    public let modelNumber: String
    public let serialNumber: String
    public let location: String
    public let firmwareVersion: String
    public let deviceID: String
    public let networkID: String

    public var id: String { "\(host):\(port)" }

    public init(
        host: String,
        port: Int = 1255,
        friendlyName: String = "",
        modelName: String = "",
        modelNumber: String = "",
        serialNumber: String = "",
        location: String = "",
        firmwareVersion: String = "",
        deviceID: String = "",
        networkID: String = ""
    ) {
        self.host = host
        self.port = port
        self.friendlyName = friendlyName
        self.modelName = modelName
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.location = location
        self.firmwareVersion = firmwareVersion
        self.deviceID = deviceID
        self.networkID = networkID
    }
}
