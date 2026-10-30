import XCTest
@testable import Neos
import NeosDomain

final class GroupNameStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "GroupNameStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testKeyIsTheSortedMemberPIDs() {
        let group = SpeakerGroup(gid: 7, name: "Bath + Den", players: [
            GroupPlayer(name: "Bath", pid: 7, role: .leader),
            GroupPlayer(name: "Den", pid: 3, role: .member)
        ])

        XCTAssertEqual(GroupNameStore.key(for: group), "3,7")
    }

    func testLoadIsEmptyWhenNothingWasSaved() {
        XCTAssertEqual(GroupNameStore.load(from: defaults), [:])
    }

    func testSavedNamesLoadBack() {
        GroupNameStore.save(["3,7": "All"], in: defaults)

        XCTAssertEqual(GroupNameStore.load(from: defaults), ["3,7": "All"])
    }

    func testCorruptDataLoadsAsEmpty() {
        defaults.set(Data("nope".utf8), forKey: "groupAliases")

        XCTAssertEqual(GroupNameStore.load(from: defaults), [:])
    }
}
