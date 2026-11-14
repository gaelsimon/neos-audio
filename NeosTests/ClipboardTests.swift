import XCTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Neos

/// Writes to a private pasteboard, so running the tests leaves the user's clipboard alone.
@MainActor
final class ClipboardTests: XCTestCase {

    func testCopyReplacesThePasteboardText() {
        #if os(macOS)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.galela.neos.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        #else
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        #endif

        Clipboard.copy("first", to: pasteboard)
        Clipboard.copy("second", to: pasteboard)

        #if os(macOS)
        XCTAssertEqual(pasteboard.string(forType: .string), "second")
        #else
        XCTAssertEqual(pasteboard.string, "second")
        #endif
    }
}
