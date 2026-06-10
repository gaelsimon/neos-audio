import XCTest

struct TopBarScreen: Screen {
    let app: XCUIApplication

    var backButton: XCUIElement { app.buttons[AccessibilityID.TopBar.backButton] }
    var forwardButton: XCUIElement { app.buttons[AccessibilityID.TopBar.forwardButton] }
    var searchField: XCUIElement { app.textFields[AccessibilityID.TopBar.searchField] }
    var profileButton: XCUIElement { app.buttons[AccessibilityID.TopBar.profileButton] }
}
