import XCTest
@testable import Neos

final class NavigationHistoryStackTests: XCTestCase {

    @MainActor
    func testInitialState() {
        let stack = NavigationHistoryStack(root: "Home")

        XCTAssertEqual(stack.current, "Home")
        XCTAssertFalse(stack.canGoBack)
        XCTAssertFalse(stack.canGoForward)
        XCTAssertEqual(stack.currentIndex, 0)
    }

    @MainActor
    func testPushAddsEntry() {
        var stack = NavigationHistoryStack(root: "Home")

        stack.push("Page1")

        XCTAssertEqual(stack.current, "Page1")
        XCTAssertTrue(stack.canGoBack)
        XCTAssertFalse(stack.canGoForward)
    }

    @MainActor
    func testGoBackReturnsPreviousEntry() {
        var stack = NavigationHistoryStack(root: "Home")
        stack.push("Page1")

        let entry = stack.goBack()

        XCTAssertEqual(entry, "Home")
        XCTAssertEqual(stack.current, "Home")
        XCTAssertFalse(stack.canGoBack)
        XCTAssertTrue(stack.canGoForward)
    }

    @MainActor
    func testGoBackAtStartReturnsNil() {
        var stack = NavigationHistoryStack(root: "Home")

        let entry = stack.goBack()

        XCTAssertNil(entry)
        XCTAssertEqual(stack.current, "Home")
    }

    @MainActor
    func testGoForwardRestoresEntry() {
        var stack = NavigationHistoryStack(root: "Home")
        stack.push("Page1")
        stack.goBack()

        let entry = stack.goForward()

        XCTAssertEqual(entry, "Page1")
        XCTAssertEqual(stack.current, "Page1")
        XCTAssertFalse(stack.canGoForward)
    }

    @MainActor
    func testGoForwardAtEndReturnsNil() {
        var stack = NavigationHistoryStack(root: "Home")
        stack.push("Page1")

        let entry = stack.goForward()

        XCTAssertNil(entry)
        XCTAssertEqual(stack.current, "Page1")
    }

    @MainActor
    func testPushAfterGoBackTruncatesForwardHistory() {
        var stack = NavigationHistoryStack(root: "Home")
        stack.push("Page1")
        stack.push("Page2")
        stack.goBack()

        XCTAssertTrue(stack.canGoForward)

        stack.push("Page3")

        XCTAssertFalse(stack.canGoForward)
        XCTAssertEqual(stack.current, "Page3")

        // Going back should reach Page1, then Home; Page2 is gone
        stack.goBack()
        XCTAssertEqual(stack.current, "Page1")
        stack.goBack()
        XCTAssertEqual(stack.current, "Home")
        XCTAssertFalse(stack.canGoBack)
    }

    @MainActor
    func testMultipleBackAndForward() {
        var stack = NavigationHistoryStack(root: "A")
        stack.push("B")
        stack.push("C")
        stack.push("D")

        stack.goBack()
        stack.goBack()
        XCTAssertEqual(stack.current, "B")
        XCTAssertTrue(stack.canGoBack)
        XCTAssertTrue(stack.canGoForward)

        stack.goForward()
        XCTAssertEqual(stack.current, "C")

        stack.goForward()
        XCTAssertEqual(stack.current, "D")
        XCTAssertFalse(stack.canGoForward)
    }

    @MainActor
    func testPushFromMiddleTruncatesCorrectly() {
        var stack = NavigationHistoryStack(root: "A")
        stack.push("B")
        stack.push("C")

        // Go back to A
        stack.goBack()
        stack.goBack()
        XCTAssertEqual(stack.current, "A")

        // Push new entry; B and C should be gone
        stack.push("X")
        XCTAssertEqual(stack.current, "X")
        XCTAssertFalse(stack.canGoForward)

        stack.goBack()
        XCTAssertEqual(stack.current, "A")
        XCTAssertFalse(stack.canGoBack)
    }

    @MainActor
    func testCurrentIndexTracksPosition() {
        var stack = NavigationHistoryStack(root: "A")
        XCTAssertEqual(stack.currentIndex, 0)

        stack.push("B")
        XCTAssertEqual(stack.currentIndex, 1)

        stack.push("C")
        XCTAssertEqual(stack.currentIndex, 2)

        stack.goBack()
        XCTAssertEqual(stack.currentIndex, 1)

        stack.goForward()
        XCTAssertEqual(stack.currentIndex, 2)
    }

    @MainActor
    func testRepeatedGoBackAtStartIsNoOp() {
        var stack = NavigationHistoryStack(root: "Home")

        XCTAssertNil(stack.goBack())
        XCTAssertNil(stack.goBack())
        XCTAssertNil(stack.goBack())

        XCTAssertEqual(stack.current, "Home")
        XCTAssertEqual(stack.currentIndex, 0)
    }

    @MainActor
    func testRepeatedGoForwardAtEndIsNoOp() {
        var stack = NavigationHistoryStack(root: "Home")
        stack.push("Page1")

        XCTAssertNil(stack.goForward())
        XCTAssertNil(stack.goForward())

        XCTAssertEqual(stack.current, "Page1")
        XCTAssertEqual(stack.currentIndex, 1)
    }

    @MainActor
    func testPushDuplicateEntriesPreservesAll() {
        var stack = NavigationHistoryStack(root: "A")
        stack.push("A")
        stack.push("A")

        XCTAssertEqual(stack.currentIndex, 2)
        XCTAssertEqual(stack.current, "A")

        stack.goBack()
        XCTAssertEqual(stack.current, "A")
        XCTAssertEqual(stack.currentIndex, 1)

        stack.goBack()
        XCTAssertEqual(stack.current, "A")
        XCTAssertEqual(stack.currentIndex, 0)
        XCTAssertFalse(stack.canGoBack)
    }

    @MainActor
    func testUpdateCurrentMutatesEntryInPlace() {
        var stack = NavigationHistoryStack(root: "Home")
        stack.push("Page1")

        stack.updateCurrent { entry in
            entry = "Page1-Updated"
        }

        XCTAssertEqual(stack.current, "Page1-Updated")

        // Going back should still reach original root
        stack.goBack()
        XCTAssertEqual(stack.current, "Home")

        // Forward should reach the updated entry
        stack.goForward()
        XCTAssertEqual(stack.current, "Page1-Updated")
    }

    @MainActor
    func testUpdateCurrentOnRootEntry() {
        var stack = NavigationHistoryStack(root: "Home")

        stack.updateCurrent { entry in
            entry = "Home-Cached"
        }

        XCTAssertEqual(stack.current, "Home-Cached")
        XCTAssertEqual(stack.currentIndex, 0)
    }
}
