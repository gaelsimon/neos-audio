import Testing
@testable import NeosDomain

@Suite("NavigationDestination")
struct NavigationDestinationTests {

    // MARK: - NavigationDestination.stableID

    @Test("home stableID is 'home'")
    func testHomeStableID() {
        #expect(NavigationDestination.home.stableID == "home")
    }

    @Test("queue stableID is 'queue'")
    func testQueueStableID() {
        #expect(NavigationDestination.queue.stableID == "queue")
    }

    @Test("settings stableID is 'settings'")
    func testSettingsStableID() {
        #expect(NavigationDestination.settings.stableID == "settings")
    }

    @Test("ampSettings stableID is 'ampSettings'")
    func testAmpSettingsStableID() {
        #expect(NavigationDestination.ampSettings.stableID == "ampSettings")
    }

    @Test("browse stableID uses only sid")
    func testBrowseStableIDUsesSID() {
        let target = BrowseTarget(sid: 5, name: "TIDAL")
        #expect(NavigationDestination.browse(target).stableID == "browse-5")
    }

    // MARK: - BrowseTarget.stableID

    @Test("BrowseTarget stableID without cid uses sid only")
    func testBrowseTargetStableIDNoCid() {
        let target = BrowseTarget(sid: 5, cid: nil, name: "TIDAL")
        #expect(target.stableID == "5")
    }

    @Test("BrowseTarget stableID with cid concatenates sid and cid")
    func testBrowseTargetStableIDWithCid() {
        let target = BrowseTarget(sid: 5, cid: "abc", name: "Album")
        #expect(target.stableID == "5abc")
    }

    // MARK: - Equality and Hashable

    @Test("BrowseTargets with same sid+cid but different name are not equal")
    func testBrowseTargetEqualityUsesAllFields() {
        let a = BrowseTarget(sid: 5, cid: "abc", name: "Album A")
        let b = BrowseTarget(sid: 5, cid: "abc", name: "Album B")
        #expect(a != b)
    }

    // MARK: - Path ID continuity

    @Test("stable path from array matches current breadcrumb format")
    func testStablePathFromArray() {
        let targets = [
            BrowseTarget(sid: 5, cid: nil, name: "TIDAL"),
            BrowseTarget(sid: 5, cid: "abc", name: "Playlists"),
            BrowseTarget(sid: 5, cid: "def", name: "My Playlist")
        ]
        let pathID = targets.map(\.stableID).joined(separator: "/")
        #expect(pathID == "5/5abc/5def")
    }

    // MARK: - browse stableID stability

    @Test("browse stableID does not change with different cid values")
    func testBrowseStableIDIgnoresCid() {
        let targetA = BrowseTarget(sid: 5, cid: nil, name: "TIDAL")
        let targetB = BrowseTarget(sid: 5, cid: "deep/nested", name: "TIDAL")
        #expect(
            NavigationDestination.browse(targetA).stableID
            == NavigationDestination.browse(targetB).stableID
        )
    }
}
