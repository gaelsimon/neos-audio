import XCTest

struct QueueScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Queue.view] }
    var header: XCUIElement { app.staticTexts[AccessibilityID.Queue.header] }
    var clearButton: XCUIElement { app.buttons[AccessibilityID.Queue.clearButton] }
}
