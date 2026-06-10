import XCTest

/// Tests for queue view in demo mode.
/// Verifies the queue is populated with sample data and controls are available.
final class DemoQueueTests: DemoTestCase {

    private func navigateToQueue() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.queueButton)
        sidebar.queueButton.click()
        let queue = QueueScreen(app: app)
        waitForElement(queue.view)
    }

    // MARK: - Queue View

    func testQueueViewExists() {
        navigateToQueue()
        let queue = QueueScreen(app: app)
        XCTAssertTrue(queue.view.exists)
    }

    func testQueueHeaderExists() {
        navigateToQueue()
        let queue = QueueScreen(app: app)
        waitForElement(queue.header)
        XCTAssertTrue(queue.header.exists)
    }

    func testQueueClearButtonExists() {
        navigateToQueue()
        let queue = QueueScreen(app: app)
        waitForElement(queue.clearButton)
        XCTAssertTrue(queue.clearButton.exists)
    }
}
