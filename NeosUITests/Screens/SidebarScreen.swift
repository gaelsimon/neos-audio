import XCTest

struct SidebarScreen: Screen {
    let app: XCUIApplication

    // Rows are list cells, not buttons, so every query matches any element type.

    var list: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.list] }
    var homeButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.home] }
    var queueButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.queue] }
    var ampCard: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.ampCard] }
    var powerButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.powerButton] }

    // Disconnected only
    var scanButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.scanButton] }
    var manualIPField: XCUIElement { app.textFields[AccessibilityID.Sidebar.manualIPField] }
    var manualConnectButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.manualConnectButton] }

    // Section headers
    var servicesSection: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.servicesSection] }
    var librarySection: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.librarySection] }

    func sourceButton(sid: Int) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Sidebar.source(sid)]
    }

    /// The first source row: a service when the speaker has one, else a local or library source.
    var firstSourceRow: XCUIElement {
        let sourceRows = NSPredicate(format: "identifier BEGINSWITH 'sidebar.source.'")
        return app.descendants(matching: .any).matching(sourceRows).firstMatch
    }
}
