import XCTest

final class DebugSidebarTest: LiveTestCase {
    func testDumpSidebarHierarchy() {
        // Check queue button via different queries
        let queue = app.descendants(matching: .any)[AccessibilityID.Sidebar.queue]
        print("=== sidebar.queue via descendants: exists=\(queue.exists) ===")

        let queueBtn = app.buttons[AccessibilityID.Sidebar.queue]
        print("=== sidebar.queue via buttons: exists=\(queueBtn.exists) ===")

        // Check library section children
        let library = app.descendants(matching: .any)[AccessibilityID.Sidebar.librarySection]
        print("=== library children count: \(library.descendants(matching: .any).count) ===")
        print("=== library buttons count: \(library.buttons.count) ===")

        // Dump any buttons containing "queue" or "Queue"
        let allButtons = app.buttons
        print("=== Total buttons: \(allButtons.count) ===")
        for i in 0..<min(allButtons.count, 30) {
            let btn = allButtons.element(boundBy: i)
            if btn.identifier.lowercased().contains("queue") || btn.label.lowercased().contains("queue") {
                print("QUEUE BUTTON FOUND: id='\(btn.identifier)', label='\(btn.label)', exists=\(btn.exists)")
            }
        }

        // Try matching text containing "Queue"
        let queueText = app.staticTexts["Queue"]
        print("=== staticTexts['Queue'] exists: \(queueText.exists) ===")

        // Check if any element with partial match exists
        let matching = app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS 'queue'"))
        print("=== elements matching 'queue' in id: count=\(matching.count) ===")
        for i in 0..<min(matching.count, 10) {
            let el = matching.element(boundBy: i)
            print("  [\(i)]: id='\(el.identifier)', type=\(el.elementType.rawValue), label='\(el.label)'")
        }
    }
}
