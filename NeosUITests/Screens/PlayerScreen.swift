import XCTest

struct PlayerScreen: Screen {
    let app: XCUIApplication

    var playPauseButton: XCUIElement { app.buttons[AccessibilityID.Player.playPause] }
    var previousButton: XCUIElement { app.buttons[AccessibilityID.Player.previous] }
    var nextButton: XCUIElement { app.buttons[AccessibilityID.Player.next] }
    var shuffleButton: XCUIElement { app.buttons[AccessibilityID.Player.shuffle] }
    var repeatButton: XCUIElement { app.buttons[AccessibilityID.Player.repeatMode] }
    var volumeMuteButton: XCUIElement { app.buttons[AccessibilityID.Player.volumeMute] }
    var volumeSlider: XCUIElement { app.otherElements[AccessibilityID.Player.volumeSlider] }
    var progressBar: XCUIElement { app.otherElements[AccessibilityID.Player.progressBar] }
    var songTitle: XCUIElement { app.staticTexts[AccessibilityID.Player.songTitle] }
    var artistName: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Player.artistName] }
    var albumArt: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Player.albumArt] }
    var qualityBadge: XCUIElement { app.staticTexts[AccessibilityID.Player.qualityBadge] }
}
