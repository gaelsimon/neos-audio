import XCTest
@testable import Neos

final class HomePreferencesTests: XCTestCase {

    override func tearDown() {
        HomePreferences.setHiddenSIDs([])
        super.tearDown()
    }

    func testHiddenSIDsEmptyByDefault() {
        HomePreferences.setHiddenSIDs([])
        XCTAssertTrue(HomePreferences.hiddenSIDs().isEmpty)
    }

    func testSetAndGetHiddenSIDs() {
        HomePreferences.setHiddenSIDs([5, 10, 15])

        let hidden = HomePreferences.hiddenSIDs()
        XCTAssertEqual(hidden, [5, 10, 15])
    }

    func testIsHiddenReturnsTrueForHiddenSID() {
        HomePreferences.setHiddenSIDs([5])

        XCTAssertTrue(HomePreferences.isHidden(sid: 5))
        XCTAssertFalse(HomePreferences.isHidden(sid: 10))
    }

    func testToggleVisibilityHidesSID() {
        HomePreferences.setHiddenSIDs([])

        HomePreferences.toggleVisibility(sid: 5)

        XCTAssertTrue(HomePreferences.isHidden(sid: 5))
    }

    func testToggleVisibilityUnhidesSID() {
        HomePreferences.setHiddenSIDs([5])

        HomePreferences.toggleVisibility(sid: 5)

        XCTAssertFalse(HomePreferences.isHidden(sid: 5))
    }

    func testToggleVisibilityDoesNotAffectOtherSIDs() {
        HomePreferences.setHiddenSIDs([5, 10])

        HomePreferences.toggleVisibility(sid: 5)

        XCTAssertFalse(HomePreferences.isHidden(sid: 5))
        XCTAssertTrue(HomePreferences.isHidden(sid: 10))
    }
}
