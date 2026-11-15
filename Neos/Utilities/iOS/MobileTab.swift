/// A tab of the iPhone and iPad app. A source and the queue have a tab of their own only beside the iPad's sidebar.
enum MobileTab: Hashable {
    case home
    case library
    case search
    case source(Int)
    case queue

    /// The tab to fall back on once a narrower window or a source going away has taken this one's tab with it.
    func showing(sourceTabs: Bool, sources: SourceSections) -> Self {
        switch self {
        case .home, .library, .search:
            self
        case .queue:
            sourceTabs ? self : .library
        case .source(let sid):
            if !sourceTabs { .library } else if sources.sids.contains(sid) { self } else { .home }
        }
    }
}

private extension SourceSections {
    var sids: Set<Int> {
        Set(library.map(\.source.sid) + services.map(\.sid) + local.map(\.sid))
    }
}
