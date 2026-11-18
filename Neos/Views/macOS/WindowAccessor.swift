import SwiftUI
import AppKit

// MARK: - Window Accessor

/// Makes the NSWindow titlebar transparent so canvas background fills edge-to-edge.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
