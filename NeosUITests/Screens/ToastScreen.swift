import XCTest

struct ToastScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Toast.view] }
    var message: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Toast.message] }
}
