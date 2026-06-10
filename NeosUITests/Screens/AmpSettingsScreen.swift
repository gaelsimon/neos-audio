import XCTest

struct AmpSettingsScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.AmpSettings.view] }

    func playerRow(_ pid: Int) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.AmpSettings.playerRow(pid)]
    }

    var powerButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.AmpSettings.powerButton] }

    /// The player-name button inside a player row (excludes the power button).
    func playerButton(_ pid: Int, label: String) -> XCUIElement {
        app.buttons.matching(identifier: AccessibilityID.AmpSettings.playerRow(pid))
            .matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    // Group management
    var leaderPicker: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Group.leaderPicker] }
    var createGroupButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Group.createButton] }
    var emptyGroupState: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Group.emptyState] }

    func memberToggle(_ pid: Int) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Group.memberToggle(pid)]
    }
}
