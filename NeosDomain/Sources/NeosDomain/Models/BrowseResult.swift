import Foundation

public struct BrowseResult: Sendable {
    public let items: [BrowseItem]
    public let returned: Int?
    public let count: Int?
    public let options: [ServiceOption]

    public init(
        items: [BrowseItem],
        returned: Int? = nil,
        count: Int? = nil,
        options: [ServiceOption] = []
    ) {
        self.items = items
        self.returned = returned
        self.count = count
        self.options = options
    }
}
