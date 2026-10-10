import SwiftUI
import AppKit

struct NoRingTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    var accessibilityID: String?

    func makeNSView(context: Context) -> FocusTrackingTextField {
        let field = FocusTrackingTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.textColor = .white
        field.delegate = context.coordinator
        field.cell?.lineBreakMode = .byTruncatingTail
        if let accessibilityID {
            field.setAccessibilityIdentifier(accessibilityID)
        }
        field.onFocusChange = { focused in
            DispatchQueue.main.async {
                context.coordinator.parent.isFocused = focused
            }
        }
        return field
    }

    func updateNSView(_ field: FocusTrackingTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        if !isFocused && field.currentEditor() != nil {
            field.window?.makeFirstResponder(nil)
        }
        if isFocused && field.currentEditor() == nil {
            // Deferred: taking focus during an update would re-enter the view cycle.
            DispatchQueue.main.async {
                guard let window = field.window, field.currentEditor() == nil else { return }
                window.makeFirstResponder(field)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NoRingTextField

        init(_ parent: NoRingTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

class FocusTrackingTextField: NSTextField {
    var onFocusChange: ((Bool) -> Void)?
    private var outsideClickMonitor: Any?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onFocusChange?(true)
            watchOutsideClicks()
        }
        return result
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        stopWatchingOutsideClicks()
        onFocusChange?(false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopWatchingOutsideClicks() }
    }

    // Resigns after the mouse-up: views shown only while editing, like recent searches, must still get their click.
    private func watchOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        var pressedOutside = false
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            let outside = !self.bounds.contains(self.convert(event.locationInWindow, from: nil))
            if event.type == .leftMouseDown {
                pressedOutside = outside
            } else if pressedOutside && outside {
                DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(nil) }
            }
            return event
        }
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    override func cancelOperation(_ sender: Any?) {
        window?.makeFirstResponder(nil)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .iBeam)
    }
}
