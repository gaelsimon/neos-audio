import XCTest

struct SidebarScreen: Screen {
    let app: XCUIApplication

    // Use descendants(matching: .any) for all elements; SwiftUI's .buttonStyle(.plain)
    // and container views can render as unexpected types in the accessibility tree.

    // Connected + Disconnected
    var scrollView: XCUIElement { app.scrollViews[AccessibilityID.Sidebar.scrollView] }

    // Connected only
    var homeButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.home] }
    var queueButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.queue] }
    var ampCard: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.ampCard] }
    var powerButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.powerButton] }

    // Disconnected only
    var scanButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.scanButton] }
    var manualIPField: XCUIElement { app.textFields[AccessibilityID.Sidebar.manualIPField] }
    var manualConnectButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.manualConnectButton] }

    // Sections (connected only)
    var servicesSection: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.servicesSection] }
    var librarySection: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Sidebar.librarySection] }

    func sourceButton(sid: Int) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Sidebar.source(sid)]
    }
}
