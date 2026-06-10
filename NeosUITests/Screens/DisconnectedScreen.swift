import XCTest

struct DisconnectedScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Disconnected.view] }
    var title: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Disconnected.title] }
    var manualConnectToggle: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Discovery.manualConnectToggle] }
}
