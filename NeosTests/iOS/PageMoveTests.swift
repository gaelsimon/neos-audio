import Testing
import NeosDomain
@testable import Neos

struct PageMoveTests {
    private static let deezer = MusicSource(sid: 5, name: "Deezer", type: "music_service", available: true)
    private let root = BrowseLocation.root(of: deezer)
    private let albums = place("Albums", cid: "albums")
    private let album = place("Albums", cid: "albums", then: "Midnight Opera", cid: "a1")

    private static func place(_ name: String, cid: String, then child: String? = nil, cid childCID: String? = nil) -> BrowseLocation {
        let rootTarget = BrowseTarget(sid: deezer.sid, name: deezer.name, imageURL: deezer.imageURL, serviceName: deezer.name)
        var stack = [rootTarget, BrowseTarget(sid: deezer.sid, cid: cid, name: name, serviceName: deezer.name)]
        if let child, let childCID {
            stack.append(BrowseTarget(sid: deezer.sid, cid: childCID, name: child, serviceName: deezer.name))
        }
        return BrowseLocation(destination: .browse(rootTarget), browseStack: stack, searchContext: nil)
    }

    @Test func aNewPlaceIsPushed() {
        #expect(PageMove(opening: albums, root: root, stack: []) == .push)
        #expect(PageMove(opening: album, root: root, stack: [albums]) == .push)
    }

    @Test func theTabsFirstPlaceEmptiesTheStack() {
        #expect(PageMove(opening: root, root: root, stack: [albums, album]) == .backToRoot)
    }

    @Test func aPlaceAlreadyOnTheStackIsGoneBackTo() {
        #expect(PageMove(opening: albums, root: root, stack: [albums, album]) == .back(to: 0))
    }

    @Test func thePageOnTopIsNotStackedAgain() {
        #expect(PageMove(opening: album, root: root, stack: [albums, album]) == .back(to: 1))
    }

    @Test func aTabWithoutAPlaceOfItsOwnPushesEvenTheQueue() {
        #expect(PageMove(opening: .queue, root: nil, stack: []) == .push)
    }
}
