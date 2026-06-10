import XCTest

struct BrowseScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Browse.view] }
    var containerArt: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Browse.containerArt] }
    var containerTitle: XCUIElement { app.staticTexts[AccessibilityID.Browse.containerTitle] }
    var playContainerButton: XCUIElement { app.buttons[AccessibilityID.Browse.playContainer] }
    var addToQueueButton: XCUIElement { app.buttons[AccessibilityID.Browse.addToQueue] }
}
