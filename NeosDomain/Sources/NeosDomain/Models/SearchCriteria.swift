import Foundation

public struct SearchCriteria: Identifiable, Equatable, Sendable {
    public let scid: Int
    public let name: String

    public var id: Int { scid }

    public init(scid: Int, name: String) {
        self.scid = scid
        self.name = name
    }
}
