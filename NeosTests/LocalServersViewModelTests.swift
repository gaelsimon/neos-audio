import XCTest
@testable import Neos
import NeosDomain

@MainActor
final class LocalServersViewModelTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "LocalServersViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testListsOnlineServersThenRememberedOfflineOnes() async {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setShown(false, for: "Old NAS")
        let mock = MockAudioService()
        mock.browseResultsBySID = [HEOSConstants.localMusicSID: BrowseResult(items: [
            BrowseItem(name: "Kantele NAS", type: .heosServer, sid: -1),
        ])]
        let vm = LocalServersViewModel(service: mock, preferences: prefs)

        await vm.load()

        XCTAssertEqual(vm.servers, [
            LocalServersViewModel.Server(name: "Kantele NAS", isOnline: true),
            LocalServersViewModel.Server(name: "Old NAS", isOnline: false),
        ])
    }

    func testAnOnlineServerWithASettingIsListedOnce() async {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setSearchable(false, for: "NASPERES")
        let mock = MockAudioService()
        mock.browseResultsBySID = [HEOSConstants.localMusicSID: BrowseResult(items: [
            BrowseItem(name: "NASPERES", type: .heosServer, sid: -2),
        ])]
        let vm = LocalServersViewModel(service: mock, preferences: prefs)

        await vm.load()

        XCTAssertEqual(vm.servers, [LocalServersViewModel.Server(name: "NASPERES", isOnline: true)])
    }

    func testTwoServersWithTheSameNameAreListedOnce() async {
        let mock = MockAudioService()
        mock.browseResultsBySID = [HEOSConstants.localMusicSID: BrowseResult(items: [
            BrowseItem(name: "NAS", type: .heosServer, sid: -1),
            BrowseItem(name: "NAS", type: .heosServer, sid: -2),
        ])]
        let vm = LocalServersViewModel(service: mock, preferences: LocalServerPreferences(defaults: defaults))

        await vm.load()

        XCTAssertEqual(vm.servers.map(\.name), ["NAS"])
    }
}
