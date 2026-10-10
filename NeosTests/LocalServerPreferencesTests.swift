import XCTest
@testable import Neos
import NeosDomain

@MainActor
final class LocalServerPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "LocalServerPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testServerIsShownAndSearchableByDefault() {
        let prefs = LocalServerPreferences(defaults: defaults)
        XCTAssertTrue(prefs.isShown("NAS") && prefs.isSearchable("NAS"))
    }

    func testHidingAServerStopsSearchingIt() {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setShown(false, for: "NAS")
        XCTAssertFalse(prefs.isSearchable("NAS"))
    }

    func testAServerCanBeShownWithoutBeingSearched() {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setSearchable(false, for: "NAS")
        XCTAssertEqual([prefs.isShown("NAS"), prefs.isSearchable("NAS")], [true, false])
    }

    func testShowingAServerAgainRestoresItsSearchSetting() {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setShown(false, for: "NAS")
        prefs.setShown(true, for: "NAS")
        XCTAssertTrue(prefs.isSearchable("NAS"))
    }

    func testShowingAServerAgainKeepsSearchOffWhenItWasOff() {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setSearchable(false, for: "NAS")
        prefs.setShown(false, for: "NAS")
        prefs.setShown(true, for: "NAS")
        XCTAssertFalse(prefs.isSearchable("NAS"))
    }

    func testSettingsSurviveARelaunch() {
        LocalServerPreferences(defaults: defaults).setShown(false, for: "NAS")
        XCTAssertFalse(LocalServerPreferences(defaults: defaults).isShown("NAS"))
    }

    func testOnlyServersWithASettingAreRemembered() {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setShown(false, for: "NAS")
        prefs.setSearchable(false, for: "NASPERES")
        prefs.setShown(true, for: "Kantele NAS")
        XCTAssertEqual(prefs.rememberedNames, ["NAS", "NASPERES"])
    }

    func testHidingOnlyFiltersServers() {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setShown(false, for: "NAS")
        let items = [
            BrowseItem(name: "NAS", type: .heosServer, sid: -1),
            BrowseItem(name: "NAS", type: .container, cid: "nas", browsable: true),
        ]
        XCTAssertEqual(items.filter(prefs.shows).map(\.type), [.container])
    }
}
