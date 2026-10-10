import NeosDomain

extension BrowseItem {
    var isMediaServer: Bool {
        type == .heosServer || type == .dlnaServer
    }
}
