#if os(macOS)
import AppKit

typealias PlatformPasteboard = NSPasteboard
#else
import UIKit

typealias PlatformPasteboard = UIPasteboard
#endif

@MainActor
enum Clipboard {
    static func copy(_ text: String, to pasteboard: PlatformPasteboard = .general) {
        #if os(macOS)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        pasteboard.string = text
        #endif
    }
}
