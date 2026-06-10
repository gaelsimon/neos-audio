import XCTest

struct NowPlayingCanvasScreen: Screen {
    let app: XCUIApplication

    var view: XCUIElement { app.descendants(matching: .any)[AccessibilityID.NowPlayingCanvas.view] }
    var closeButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.NowPlayingCanvas.closeButton] }
    var artwork: XCUIElement { app.descendants(matching: .any)[AccessibilityID.NowPlayingCanvas.artwork] }
    var artistName: XCUIElement { app.descendants(matching: .any)[AccessibilityID.NowPlayingCanvas.artistName] }
}
