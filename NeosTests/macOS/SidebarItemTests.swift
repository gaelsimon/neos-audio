import Testing
@testable import Neos

struct SidebarItemTests {
    private let deezer = BrowseTarget(sid: 5, name: "Deezer")
    private let albums = BrowseTarget(sid: 5, cid: "albums", name: "Albums")

    @Test func homeSelectsHome() {
        #expect(SidebarItem(destination: .home, browseStack: []) == .home)
    }

    @Test func theQueueSelectsTheQueue() {
        #expect(SidebarItem(destination: .queue, browseStack: []) == .queue)
    }

    @Test func aSourceStaysSelectedBelowItsFirstPage() {
        #expect(SidebarItem(destination: .browse(deezer), browseStack: [deezer, albums]) == .source(5))
    }

    @Test(arguments: [NavigationDestination.settings, .ampSettings])
    func settingsSelectNoRow(destination: NavigationDestination) {
        #expect(SidebarItem(destination: destination, browseStack: []) == nil)
    }

    @Test func aBrowsePageWithoutAPathSelectsNoRow() {
        #expect(SidebarItem(destination: .browse(deezer), browseStack: []) == nil)
    }
}
