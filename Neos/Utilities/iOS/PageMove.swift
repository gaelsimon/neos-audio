/// What opening a place does to a tab's stack of pages: a place already there is gone back to, never stacked twice.
enum PageMove: Equatable {
    case backToRoot
    /// The index of the page that ends on top.
    case back(to: Int)
    case push

    init(opening location: BrowseLocation, root: BrowseLocation?, stack: [BrowseLocation]) {
        if location == root {
            self = .backToRoot
        } else if let index = stack.lastIndex(of: location) {
            self = .back(to: index)
        } else {
            self = .push
        }
    }
}
