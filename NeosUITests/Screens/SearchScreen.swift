import XCTest

struct SearchScreen: Screen {
    let app: XCUIApplication

    var searchField: XCUIElement { app.textFields[AccessibilityID.TopBar.searchField] }
    var clearButton: XCUIElement { app.buttons[AccessibilityID.Search.clearButton] }
    var resultsView: XCUIElement { app.scrollViews[AccessibilityID.Search.resultsView] }
    var historyOverlay: XCUIElement { app.otherElements[AccessibilityID.Search.historyOverlay] }
    var clearHistoryButton: XCUIElement { app.buttons[AccessibilityID.Search.clearHistoryButton] }
}
