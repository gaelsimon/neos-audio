import Foundation

public struct Player: Identifiable, Equatable, Sendable {
    public let pid: Int
    public let name: String
    public let model: String
    public let version: String
    public let ip: String
    public let network: NetworkType
    public let lineout: Int
    public let serial: String
    public var gid: Int?
    public var control: Int?

    public var id: Int { pid }

    public init(
        pid: Int,
        name: String,
        model: String = "",
        version: String = "",
        ip: String = "",
        network: NetworkType = .wifi,
        lineout: Int = 0,
        serial: String = "",
        gid: Int? = nil,
        control: Int? = nil
    ) {
        self.pid = pid
        self.name = name
        self.model = model
        self.version = version
        self.ip = ip
        self.network = network
        self.lineout = lineout
        self.serial = serial
        self.gid = gid
        self.control = control
    }
}

public enum NetworkType: String, Sendable, Codable {
    case wifi
    case wired
    case unknown
}
