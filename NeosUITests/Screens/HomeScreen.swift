import XCTest

struct HomeScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Home.view] }
    var header: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Home.header] }
    var configButton: XCUIElement { app.buttons[AccessibilityID.Home.configButton] }
    var refreshButton: XCUIElement { app.buttons[AccessibilityID.Home.refreshButton] }
    var emptyState: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Home.emptyState] }
}
