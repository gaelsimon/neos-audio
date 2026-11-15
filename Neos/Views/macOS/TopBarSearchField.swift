import AppKit
import SwiftUI

/// AppKit because SwiftUI's search field needs macOS 15 to take focus from a shortcut.
struct TopBarSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    /// The clear button resets the filters too; deleting the text keeps them.
    let onClear: () -> Void

    func makeNSView(context: Context) -> FocusTrackingSearchField {
        let field = FocusTrackingSearchField()
        field.placeholderString = "Search"
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.textColor = .white
        field.delegate = context.coordinator
        field.cell?.lineBreakMode = .byTruncatingTail
        field.setAccessibilityIdentifier(AccessibilityID.TopBar.searchField)
        if let cancelButton = (field.cell as? NSSearchFieldCell)?.cancelButtonCell {
            cancelButton.target = context.coordinator
            cancelButton.action = #selector(Coordinator.clear)
            cancelButton.setAccessibilityIdentifier(AccessibilityID.Search.clearButton)
        }
        field.onFocusChange = { focused in
            DispatchQueue.main.async {
                context.coordinator.parent.isFocused = focused
            }
        }
        return field
    }

    func updateNSView(_ field: FocusTrackingSearchField, context: Context) {
        context.coordinator.parent = self
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

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: TopBarSearchField

        init(_ parent: TopBarSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        @objc func clear() {
            parent.onClear()
        }
    }
}

final class FocusTrackingSearchField: NSSearchField {
    var onFocusChange: ((Bool) -> Void)?
    private var outsideClickMonitor: Any?

    override static var cellClass: AnyClass? {
        get { SearchFieldCell.self }
        set {}
    }

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

    // Escape leaves the field and keeps the query, where a search field would clear it.
    override func cancelOperation(_ sender: Any?) {
        window?.makeFirstResponder(nil)
    }

    override func resetCursorRects() {
        guard let cell = cell as? NSSearchFieldCell else { return super.resetCursorRects() }
        addCursorRect(cell.searchTextRect(forBounds: bounds), cursor: .iBeam)
    }
}

// Without a bezel, macOS 26 lays the editor over the whole field: the text covers the magnifier and the clear button gets no click.
final class SearchFieldCell: NSSearchFieldCell {
    private var editorFrame: NSRect?

    override func select(
        withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, start: Int, length: Int
    ) {
        let frame = textFrame(in: rect)
        defer { editorFrame = nil }
        super.select(withFrame: frame, in: controlView, editor: editor, delegate: delegate, start: start, length: length)
    }

    override func edit(
        withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, event: NSEvent?
    ) {
        let frame = textFrame(in: rect)
        defer { editorFrame = nil }
        super.edit(withFrame: frame, in: controlView, editor: editor, delegate: delegate, event: event)
    }

    // Where AppKit does inset the editor itself, it asks again with the frame already inset.
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        rect == editorFrame ? rect : super.drawingRect(forBounds: rect)
    }

    private func textFrame(in rect: NSRect) -> NSRect {
        let frame = drawingRect(forBounds: rect)
        editorFrame = frame
        return frame
    }
}
