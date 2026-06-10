import XCTest

struct SettingsScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Settings.view] }

    // MARK: - Account Form Elements

    var emailField: XCUIElement { app.textFields[AccessibilityID.Settings.emailField] }
    var passwordField: XCUIElement { app.secureTextFields[AccessibilityID.Settings.passwordField] }
    var signInButton: XCUIElement { app.buttons[AccessibilityID.Settings.signInButton] }
    var signOutButton: XCUIElement { app.buttons[AccessibilityID.Settings.signOutButton] }
    var signedInUser: XCUIElement { app.staticTexts[AccessibilityID.Settings.signedInUser] }
    var signInError: XCUIElement { app.staticTexts[AccessibilityID.Settings.signInError] }
}
