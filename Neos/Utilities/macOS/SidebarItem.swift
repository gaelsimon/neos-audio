/// A row of the Mac sidebar.
enum SidebarItem: Hashable {
    case home
    case source(Int)
    case queue

    /// The row that leads to the current page, if one does; a source stays selected on every page below it.
    init?(destination: NavigationDestination, browseStack: [BrowseTarget]) {
        switch destination {
        case .home:
            self = .home
        case .queue:
            self = .queue
        case .browse:
            guard let root = browseStack.first else { return nil }
            self = .source(root.sid)
        case .settings, .ampSettings:
            return nil
        }
    }
}
