import XCTest
@testable import Neos

final class ToastHostsTests: XCTestCase {
    private let page = UUID()
    private let otherTab = UUID()
    private let sheet = UUID()

    func testASheetTakesTheToastFromThePageUnderIt() {
        var hosts = ToastHosts()
        hosts.enter(page, depth: 0)

        hosts.enter(sheet, depth: 1)

        XCTAssertFalse(hosts.isFrontmost(depth: 0))
    }

    func testTheSheetShowsTheToast() {
        var hosts = ToastHosts()
        hosts.enter(page, depth: 0)

        hosts.enter(sheet, depth: 1)

        XCTAssertTrue(hosts.isFrontmost(depth: 1))
    }

    func testAPageThatAppearsAgainUnderASheetLeavesItTheToast() {
        var hosts = ToastHosts()
        hosts.enter(page, depth: 0)
        hosts.enter(sheet, depth: 1)

        hosts.enter(otherTab, depth: 0)

        XCTAssertTrue(hosts.isFrontmost(depth: 1))
    }

    func testThePagesGetTheToastBackOnceTheSheetCloses() {
        var hosts = ToastHosts()
        hosts.enter(page, depth: 0)
        hosts.enter(sheet, depth: 1)

        hosts.leave(sheet)

        XCTAssertTrue(hosts.isFrontmost(depth: 0))
    }

    func testAHostEnteringTwiceLeavesOnce() {
        var hosts = ToastHosts()
        hosts.enter(page, depth: 0)
        hosts.enter(sheet, depth: 1)
        hosts.enter(sheet, depth: 1)

        hosts.leave(sheet)

        XCTAssertTrue(hosts.isFrontmost(depth: 0))
    }

    func testNobodyShowsTheToastWhenNoHostIsUp() {
        XCTAssertFalse(ToastHosts().isFrontmost(depth: 0))
    }
}
