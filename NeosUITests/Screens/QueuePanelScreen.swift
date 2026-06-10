import XCTest

struct QueuePanelScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.QueuePanel.view] }
    var toggleButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.QueuePanel.toggleButton] }
    var emptyState: XCUIElement { app.descendants(matching: .any)[AccessibilityID.QueuePanel.emptyState] }
    var historySection: XCUIElement { app.descendants(matching: .any)[AccessibilityID.QueuePanel.historySection] }
    var nowPlayingSection: XCUIElement { app.descendants(matching: .any)[AccessibilityID.QueuePanel.nowPlayingSection] }
    var upNextSection: XCUIElement { app.descendants(matching: .any)[AccessibilityID.QueuePanel.upNextSection] }

    func upNextRow(_ qid: Int) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.QueuePanel.upNextRow(qid)]
    }

    func historyRow(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.QueuePanel.historyRow(index)]
    }
}
