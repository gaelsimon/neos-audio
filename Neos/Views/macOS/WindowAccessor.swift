import SwiftUI
import AppKit

// MARK: - Window Accessor

/// Makes the NSWindow titlebar transparent so canvas background fills edge-to-edge.
struct WindowAccessor: NSViewRepresentable {
    func makeCoordinator() -> TrafficLightInset { TrafficLightInset() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isOpaque = false
                window.backgroundColor = .clear
                context.coordinator.attach(to: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Moves the traffic lights in from the corner; a SwiftUI toolbar would too, but it swallows every click in the title strip.
final class TrafficLightInset {
    private let offset = CGSize(width: 8, height: 10)
    private var defaultOrigins: [NSWindow.ButtonType: NSPoint] = [:]
    private var defaultBarHeight: CGFloat = 0
    private var observers: [NSObjectProtocol] = []

    func attach(to window: NSWindow) {
        guard observers.isEmpty else { return }
        apply(to: window)
        // AppKit lays the buttons out again on every resize and on leaving full screen.
        let names = [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification, NSWindow.didExitFullScreenNotification]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                DispatchQueue.main.async {
                    if let window { self?.apply(to: window) }
                }
            }
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func apply(to window: NSWindow) {
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = types.compactMap { type in window.standardWindowButton(type).map { (type, $0) } }
        guard let bar = buttons.first?.1.superview else { return }
        if defaultOrigins.isEmpty {
            buttons.forEach { defaultOrigins[$0.0] = $0.1.frame.origin }
            defaultBarHeight = bar.frame.height
        }
        for (type, button) in buttons {
            guard let origin = defaultOrigins[type] else { continue }
            button.setFrameOrigin(NSPoint(x: origin.x + offset.width, y: origin.y - offset.height))
        }
        bar.frame.size.height = defaultBarHeight + offset.height
    }
}
